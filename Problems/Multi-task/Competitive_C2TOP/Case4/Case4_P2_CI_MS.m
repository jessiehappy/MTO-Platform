classdef Case4_P2_CI_MS < Problem
    % <Multi> <Competitive>

    methods
        function obj = Case4_P2_CI_MS(name)
            obj = obj@Problem(name);
            obj.sub_eva = 1000 * 100;
        end

        function Tasks = getTasks(obj)
            Tasks = benchmark_CEC17_MTSO_Competitive(2, 4);
        end
    end
end
