classdef SBO < Algorithm
    % <Many> <None>

    %------------------------------- Reference --------------------------------
    % @Article{Liaw2019SBO,
    %   author     = {Liaw, Rung-Tzuo and Ting, Chuan-Kang},
    %   journal    = {Proceedings of the AAAI Conference on Artificial Intelligence},
    %   title      = {Evolutionary Manytasking Optimization Based on Symbiosis in Biocoenosis},
    %   year       = {2019},
    %   month      = {Jul.},
    %   number     = {01},
    %   pages      = {4295-4303},
    %   volume     = {33},
    %   doi        = {10.1609/aaai.v33i01.33014295},
    % }
    %--------------------------------------------------------------------------

    %------------------------------- Copyright --------------------------------
    % Copyright (c) 2022 Yanchi Li. You are free to use the MTO-Platform for
    % research purposes. All publications which use this platform or any code
    % in the platform should acknowledge the use of "MTO-Platform" and cite
    % or footnote "https://github.com/intLyc/MTO-Platform"
    %--------------------------------------------------------------------------

    properties (SetAccess = private)
        benefit = 0.25;
        harm = 0.5;
        mu = 2;
        mum = 5;
    end

    methods
        function parameter = getParameter(obj)
            parameter = {'benefit: Beneficial factor', num2str(obj.benefit), ...
                        'harm: Harmful factor', num2str(obj.harm), ...
                        'mu: index of Simulated Binary Crossover', num2str(obj.mu), ...
                        'mum: index of polynomial mutation', num2str(obj.mum)};
        end

        function obj = setParameter(obj, parameter_cell)
            count = 1;
            obj.benefit = str2double(parameter_cell{count}); count = count + 1;
            obj.harm = str2double(parameter_cell{count}); count = count + 1;
            obj.mu = str2double(parameter_cell{count}); count = count + 1;
            obj.mum = str2double(parameter_cell{count}); count = count + 1;
        end

        function data = run(obj, Tasks, run_parameter_list)
            sub_pop = run_parameter_list(1);
            sub_eva = run_parameter_list(2);
            pop_size = sub_pop * length(Tasks);
            eva_num = sub_eva * length(Tasks);
            tic

            RIJ = 0.5 * ones(length(Tasks), length(Tasks)); % transfer rates
            MIJ = ones(length(Tasks), length(Tasks)); % benefit and benefit
            NIJ = ones(length(Tasks), length(Tasks)); % neutral and neutral
            CIJ = ones(length(Tasks), length(Tasks)); % harm and harm
            OIJ = ones(length(Tasks), length(Tasks)); % neutral and benefit
            PIJ = ones(length(Tasks), length(Tasks)); % benefit and harm
            AIJ = ones(length(Tasks), length(Tasks)); % harm and neutral

            % initialize
            [population_temp, fnceval_calls, bestobj, data.bestX] = initializeMT(IndividualSBO, sub_pop, Tasks, max([Tasks.dims]) * ones(1, length(Tasks)));
            data.convergence(:, 1) = bestobj;
            population = IndividualSBO.empty();
            for t = 1:length(Tasks)
                [~, rank] = sort([population_temp{t}.factorial_costs]);
                for i = 1:length(population_temp{t})
                    population_temp{t}(rank(i)).rank_o = i;
                    population_temp{t}(rank(i)).skill_factor = t;
                    population_temp{t}(rank(i)).belonging_task = t;
                end
                population = [population, population_temp{t}];
            end

            generation = 1;
            while fnceval_calls < eva_num
                generation = generation + 1;

                offspring = IndividualSBO.empty();
                for t = 1:length(Tasks)
                    t_idx = [population.skill_factor] == t;
                    find_idx = find(t_idx);
                    % generation
                    offspring_t = OperatorGA.generate(0, population(t_idx), Tasks(t), obj.mu, obj.mum);
                    for i = 1:length(offspring_t)
                        offspring_t(i).skill_factor = t;
                        offspring_t(i).belonging_task = t;
                        offspring_t(i).rank_o = population(find_idx(i)).rank_o;
                    end
                    offspring = [offspring, offspring_t];
                end

                for t = 1:length(Tasks)
                    t_idx = [offspring.skill_factor] == t;
                    find_idx = find(t_idx);
                    % knowledge transfer
                    [~, transfer_task] = max(RIJ(t, [1:t - 1, t + 1:end])); % find transferred task
                    if transfer_task >= t
                        transfer_task = transfer_task + 1;
                    end
                    if rand() < RIJ(t, transfer_task)
                        Si = floor(sub_pop * RIJ(t, transfer_task)); % transfer quantity
                        ind1 = randperm(sub_pop, Si);
                        ind2 = randperm(sub_pop, Si);
                        this_pos = find(t_idx);
                        trans_pos = find([offspring.skill_factor] == transfer_task);
                        for i = 1:Si
                            offspring(this_pos(ind1(i))).rnvec = offspring(trans_pos(ind2(i))).rnvec;
                            offspring(this_pos(ind1(i))).belonging_task = transfer_task;
                        end
                    end

                    [offspring(t_idx), calls] = evaluate(offspring(t_idx), Tasks(t), 1);
                    fnceval_calls = fnceval_calls + calls;

                    [~, rank] = sort([offspring(t_idx).factorial_costs]);
                    for i = 1:length(rank)
                        offspring(find_idx(rank(i))).rank_c = i;
                    end

                    % selection
                    population_temp = [population(t_idx), offspring(t_idx)];
                    [~, rank] = sort([population_temp.factorial_costs]);
                    population(t_idx) = population_temp(rank(1:sub_pop));
                    [~, rank] = sort([population(t_idx).factorial_costs]);
                    for i = 1:length(rank)
                        population(find_idx(rank(i))).rank_o = i;
                    end

                    [bestobj_temp, idx] = min([population(t_idx).factorial_costs]);
                    if bestobj_temp < bestobj(t)
                        bestobj(t) = bestobj_temp;
                        data.bestX{t} = population(find_idx(idx)).rnvec;
                    end
                end

                for t = 1:length(Tasks)
                    % update symbiosis
                    t_idx = find([offspring.skill_factor] == t & [offspring.belonging_task] ~= t);
                    find_idx = find(t_idx);
                    rank_c = [offspring(t_idx).rank_c];
                    rank_o = [offspring(t_idx).rank_o];
                    for k = 1:length(t_idx)
                        if rank_c(k) < sub_pop * obj.benefit
                            if rank_o(k) < sub_pop * obj.benefit
                                MIJ(t, offspring(find_idx(k)).belonging_task) = MIJ(t, offspring(find_idx(k)).belonging_task) + 1;
                            elseif rank_o(k) > sub_pop * (1 - obj.harm)
                                PIJ(t, offspring(find_idx(k)).belonging_task) = PIJ(t, offspring(find_idx(k)).belonging_task) + 1;
                            else
                                OIJ(t, offspring(find_idx(k)).belonging_task) = OIJ(t, offspring(find_idx(k)).belonging_task) + 1;
                            end
                        elseif rank_c(k) > sub_pop * (1 - obj.harm)
                            if rank_o(k) > sub_pop * (1 - obj.harm)
                                CIJ(t, offspring(find_idx(k)).belonging_task) = CIJ(t, offspring(find_idx(k)).belonging_task) + 1;
                            end
                        else
                            if rank_o(k) > sub_pop * (1 - obj.harm)
                                AIJ(t, offspring(find_idx(k)).belonging_task) = AIJ(t, offspring(find_idx(k)).belonging_task) + 1;
                            elseif rank_o(k) >= sub_pop * obj.benefit && rank_o(k) <= sub_pop * (1 - obj.harm)
                                NIJ(t, offspring(find_idx(k)).belonging_task) = NIJ(t, offspring(find_idx(k)).belonging_task) + 1;
                            end
                        end
                    end
                end
                % update transfer rates
                RIJ = (MIJ + OIJ + PIJ) ./ (MIJ + OIJ + PIJ + AIJ + CIJ + NIJ);

                data.convergence(:, generation) = bestobj;
            end
            data.bestX = uni2real(data.bestX, Tasks);
            data.clock_time = toc;
        end
    end
end
