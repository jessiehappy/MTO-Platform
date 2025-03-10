classdef EMEA < Algorithm
    % <Multi> <None>

    %------------------------------- Reference --------------------------------
    % @Article{Feng2019EMEA,
    %   author     = {Feng, Liang and Zhou, Lei and Zhong, Jinghui and Gupta, Abhishek and Ong, Yew-Soon and Tan, Kay-Chen and Qin, A. K.},
    %   journal    = {IEEE Transactions on Cybernetics},
    %   title      = {Evolutionary Multitasking via Explicit Autoencoding},
    %   year       = {2019},
    %   number     = {9},
    %   pages      = {3457-3470},
    %   volume     = {49},
    %   doi        = {10.1109/TCYB.2018.2845361},
    % }
    %--------------------------------------------------------------------------

    %------------------------------- Copyright --------------------------------
    % Copyright (c) 2022 Yanchi Li. You are free to use the MTO-Platform for
    % research purposes. All publications which use this platform or any code
    % in the platform should acknowledge the use of "MTO-Platform" and cite
    % or footnote "https://github.com/intLyc/MTO-Platform"
    %--------------------------------------------------------------------------

    properties (SetAccess = private)
        Op = 'GA/DE';
        Snum = 10;
        Gap = 10;
        GA_mu = 2;
        GA_mum = 5;
        DE_F = 0.5;
        DE_CR = 0.9;
    end

    methods
        function parameter = getParameter(obj)
            parameter = {'Op: Operator (Split with /)', obj.Op, ...
                        'S: Transfer num', num2str(obj.Snum), ...
                        'G: Transfer Gap', num2str(obj.Gap), ...
                        'mu: index of Simulated Binary Crossover', num2str(obj.GA_mu), ...
                        'mum: index of polynomial mutation', num2str(obj.GA_mum), ...
                        'F: DE Mutation Factor', num2str(obj.DE_F), ...
                        'CR: DE Crossover Probability', num2str(obj.DE_CR)};
        end

        function obj = setParameter(obj, parameter_cell)
            count = 1;
            obj.Op = parameter_cell{count}; count = count + 1;
            obj.Snum = str2double(parameter_cell{count}); count = count + 1;
            obj.Gap = str2double(parameter_cell{count}); count = count + 1;
            obj.GA_mu = str2double(parameter_cell{count}); count = count + 1;
            obj.GA_mum = str2double(parameter_cell{count}); count = count + 1;
            obj.DE_F = str2double(parameter_cell{count}); count = count + 1;
            obj.DE_CR = str2double(parameter_cell{count}); count = count + 1;
        end

        function data = run(obj, Tasks, run_parameter_list)
            sub_pop = run_parameter_list(1);
            sub_eva = run_parameter_list(2);
            pop_size = sub_pop * length(Tasks);
            eva_num = sub_eva * length(Tasks);
            tic

            op_list = split(obj.Op, '/');

            % initialize
            [population, fnceval_calls, bestobj, data.bestX] = initializeMT(Individual, sub_pop, Tasks, [Tasks.dims]);
            data.convergence(:, 1) = bestobj;

            generation = 1;
            while fnceval_calls < eva_num
                generation = generation + 1;

                for t = 1:length(Tasks)
                    parent = population{t};

                    % generation
                    op_idx = mod(t - 1, length(op_list)) + 1;
                    op = op_list{op_idx};
                    switch op
                        case 'GA'
                            offspring = OperatorGA.generate(0, parent, Tasks(t), obj.GA_mu, obj.GA_mum);
                        case 'DE'
                            offspring = OperatorDE.generate(0, parent, Tasks(t), obj.DE_F, obj.DE_CR);
                    end

                    % Transfer
                    if obj.Snum > 0 && mod(generation, obj.Gap) == 0
                        inject_num = round(obj.Snum ./ (length(Tasks) - 1));
                        inject_pop = Individual.empty();
                        for tt = 1:length(Tasks)
                            if t == tt
                                continue;
                            end
                            [~, curr_best_idx] = sort([population{t}.factorial_costs]);
                            curr_pop = population{t}(curr_best_idx);
                            curr_pop_rnvec = reshape([curr_pop.rnvec], length(curr_pop(1).rnvec), length(curr_pop))';

                            [~, his_best_idx] = sort([population{tt}.factorial_costs]);
                            his_pop = population{tt}(his_best_idx);
                            his_pop_rnvec = reshape([his_pop.rnvec], length(his_pop(1).rnvec), length(his_pop))';
                            his_best_rnvec = his_pop_rnvec(1:inject_num, :);

                            % map to original
                            curr_pop_rnvec = (Tasks(t).Ub - Tasks(t).Lb) .* curr_pop_rnvec + Tasks(t).Lb;
                            his_pop_rnvec = (Tasks(tt).Ub - Tasks(tt).Lb) .* his_pop_rnvec + Tasks(tt).Lb;
                            his_best_rnvec = (Tasks(tt).Ub - Tasks(tt).Lb) .* his_best_rnvec + Tasks(tt).Lb;

                            inject = mDA(curr_pop_rnvec, his_pop_rnvec, his_best_rnvec);

                            % mat to [0,1]
                            inject = (inject - Tasks(t).Lb) ./ (Tasks(t).Ub - Tasks(t).Lb);

                            for i = 1:size(inject, 1)
                                c = Individual();
                                c.rnvec = inject(i, :);
                                c.rnvec(c.rnvec > 1) = 1;
                                c.rnvec(c.rnvec < 0) = 0;
                                inject_pop = [inject_pop, c];
                            end
                        end
                        replace_idx = randperm(length(offspring), length(inject_pop));
                        offspring(replace_idx) = inject_pop;
                    end

                    [offspring, calls] = evaluate(offspring, Tasks(t), 1);
                    fnceval_calls = fnceval_calls + calls;

                    [bestobj_offspring, idx] = min([offspring.factorial_costs]);
                    if bestobj_offspring < bestobj(t)
                        bestobj(t) = bestobj_offspring;
                        data.bestX{t} = offspring(idx).rnvec;
                    end
                    data.convergence(t, generation) = bestobj(t);

                    % selection
                    switch op
                        case 'GA'
                            population{t} = [population{t}, offspring];
                            [~, rank] = sort([population{t}.factorial_costs]);
                            population{t} = population{t}(rank(1:sub_pop));
                        case 'DE'
                            replace = [population{t}.factorial_costs] > [offspring.factorial_costs];
                            population{t}(replace) = offspring(replace);
                    end
                end
            end
            data.bestX = uni2real(data.bestX, Tasks);
            data.clock_time = toc;
        end
    end
end
