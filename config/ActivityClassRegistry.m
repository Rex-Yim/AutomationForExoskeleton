%% ActivityClassRegistry — unified activity IDs for USC-HAD + HuGaDB (multiclass)
% Raw USC-HAD activity index 1..12 (trial.label). HuGaDB per-sample act 1..8.
% Class 0 = unknown / skip window.

classdef ActivityClassRegistry
    properties (Constant)
        % Order must match unified class index 1..K
        CLASS_NAMES = { ...
            'WalkLevel', 'StairsUp', 'StairsDown', 'Run', 'Jump', ...
            'Sit', 'Stand', 'Sleep', 'ElevatorUp', 'ElevatorDown', ...
            'SitToStand', 'StandToSit' ...
        };
        N_CLASSES = 12;
        % USC-HAD: 1=WalkF 2=WalkL 3=WalkR 4=Up 5=Down 6=Run 7=Jump 8=Sit 9=Stand 10=Sleep 11=ElUp 12=ElDown
        USCHAD_ACT_TO_CLASS = [1 1 1 2 3 4 5 6 7 8 9 10];
        % HuGaDB v2: 1 Sit 2 Stand 3 SitToStand 4 StandToSit 5 Walk 6 StairsUp 7 StairsDown 8 Run
        HUGADB_ACT_TO_CLASS = [6 7 11 12 1 2 3 4];
    end

    methods (Static)
        function c = mapUSCHAD(actId)
            m = ActivityClassRegistry.USCHAD_ACT_TO_CLASS;
            if isempty(actId) || numel(actId) ~= 1
                c = 0;
                return;
            end
            a = actId(1);
            if a < 1 || a > numel(m) || floor(a) ~= a
                c = 0;
            else
                c = m(a);
            end
        end

        function c = mapHuGaDB(actId)
            m = ActivityClassRegistry.HUGADB_ACT_TO_CLASS;
            if isempty(actId) || numel(actId) ~= 1
                c = 0;
                return;
            end
            a = actId(1);
            if a < 1 || a > numel(m) || floor(a) ~= a
                c = 0;
            else
                c = m(a);
            end
        end

        function y = hugadbWindowClass(chunk)
            chunk = chunk(:);
            v = zeros(numel(chunk), 1);
            for i = 1:numel(chunk)
                v(i) = ActivityClassRegistry.mapHuGaDB(chunk(i));
            end
            v = v(v > 0);
            if isempty(v)
                y = 0;
            else
                y = mode(v);
            end
        end

        function tf = isLocomotionClass(classId)
            % Binary exo assist gating: walk-level, stairs, run only (not jump)
            tf = ismember(classId, [1, 2, 3, 4]);
        end

        function name = className(classId)
            if classId < 1 || classId > ActivityClassRegistry.N_CLASSES
                name = 'Unknown';
            else
                name = ActivityClassRegistry.CLASS_NAMES{classId};
            end
        end
    end
end
