classdef MFEA_II < Algorithm
    % <Multi> <None>

    %------------------------------- Reference --------------------------------
    % @Article{Bali2020MFEA2,
    %   author     = {Bali, Kavitesh Kumar and Ong, Yew-Soon and Gupta, Abhishek and Tan, Puay Siew},
    %   journal    = {IEEE Transactions on Evolutionary Computation},
    %   title      = {Multifactorial Evolutionary Algorithm With Online Transfer Parameter Estimation: MFEA-II},
    %   year       = {2020},
    %   number     = {1},
    %   pages      = {69-83},
    %   volume     = {24},
    %   doi        = {10.1109/TEVC.2019.2906927},
    % }
    %--------------------------------------------------------------------------

    %------------------------------- Copyright --------------------------------
    % Copyright (c) 2022 Yanchi Li. You are free to use the MTO-Platform for
    % research purposes. All publications which use this platform or any code
    % in the platform should acknowledge the use of "MTO-Platform" and cite
    % or footnote "https://github.com/intLyc/MTO-Platform"
    %--------------------------------------------------------------------------

    properties (SetAccess = private)
        mu = 2;
        mum = 5;
        probswap = 0.5;
    end

    methods
        function parameter = getParameter(obj)
            parameter = {'mu: index of Simulated Binary Crossover', num2str(obj.mu), ...
                        'mum: index of polynomial mutation', num2str(obj.mum), ...
                        'probSwap: Variable Swap Probability', num2str(obj.probswap)};
        end

        function obj = setParameter(obj, parameter_cell)
            count = 1;
            obj.mu = str2double(parameter_cell{count}); count = count + 1;
            obj.mum = str2double(parameter_cell{count}); count = count + 1;
            obj.probswap = str2double(parameter_cell{count}); count = count + 1;
        end

        function data = run(obj, Tasks, run_parameter_list)
            sub_pop = run_parameter_list(1);
            sub_eva = run_parameter_list(2);
            pop_size = sub_pop * length(Tasks);
            eva_num = sub_eva * length(Tasks);
            tic

            % initialize
            [population, fnceval_calls, bestobj, data.bestX] = initializeMF(Individual, pop_size, Tasks, max([Tasks.dims]));
            data.convergence(:, 1) = bestobj;

            generation = 1;
            while fnceval_calls < eva_num
                generation = generation + 1;

                % Extract task specific data sets
                for t = 1:length(Tasks)
                    subpops(t).data = [];
                end
                for i = 1:length(population)
                    subpops(population(i).skill_factor).data = [subpops(population(i).skill_factor).data; population(i).rnvec];
                end
                RMP = learnRMP(subpops, [Tasks.dims]); % learning RMP matrix online at every generation.

                % generation
                [offspring, calls] = OperatorMFEA2.generate(1, population, Tasks, RMP, obj.mu, obj.mum, obj.probswap);
                fnceval_calls = fnceval_calls + calls;

                % selection
                [population, bestobj, data.bestX] = selectMF(population, offspring, Tasks, pop_size, bestobj, data.bestX);
                data.convergence(:, generation) = bestobj;
            end
            data.bestX = uni2real(data.bestX, Tasks);
            data.clock_time = toc;
        end
    end
end
