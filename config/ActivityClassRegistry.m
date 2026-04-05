%% ActivityClassRegistry — native activity IDs per dataset (multiclass, no unified mapping)
% USC-HAD: trial label 1..12. HuGaDB: per-sample act 1..12.
% Class 0 = unknown / skip window.

classdef ActivityClassRegistry
    properties (Constant)
        USCHAD_N_CLASSES = 12;
        USCHAD_CLASS_NAMES = { ...
            'WalkForward', 'WalkLeft', 'WalkRight', 'GoUpstairs', ...
            'GoDownstairs', 'RunForward', 'Jump', 'Sit', 'Stand', ...
            'Sleep', 'ElevatorUp', 'ElevatorDown' ...
        };

        HUGADB_N_CLASSES = 12;
        HUGADB_CLASS_NAMES = { ...
            'Walking', 'Running', 'GoingUp', 'GoingDown', ...
            'Sitting', 'SittingDown', 'StandingUp', 'Standing', ...
            'Bicycling', 'ElevatorUp', 'ElevatorDown', 'SittingInCar' ...
        };
    end

    methods (Static)
        function c = validateUSCHADNative(actId)
            if isempty(actId) || numel(actId) ~= 1
                c = 0;
                return;
            end
            a = actId(1);
            if a < 1 || a > ActivityClassRegistry.USCHAD_N_CLASSES || floor(a) ~= a
                c = 0;
            else
                c = a;
            end
        end

        function c = mapHuGaDBNative(actId)
            if isempty(actId) || numel(actId) ~= 1
                c = 0;
                return;
            end
            a = actId(1);
            if a < 1 || a > ActivityClassRegistry.HUGADB_N_CLASSES || floor(a) ~= a
                c = 0;
            else
                c = a;
            end
        end

        function y = hugadbNativeWindowClass(chunk)
            chunk = chunk(:);
            v = zeros(numel(chunk), 1);
            for i = 1:numel(chunk)
                v(i) = ActivityClassRegistry.mapHuGaDBNative(chunk(i));
            end
            v = v(v > 0);
            if isempty(v)
                y = 0;
            else
                y = mode(v);
            end
        end

        function ids = binaryPositiveIdsUSCHAD()
            ids = [1, 2, 3, 4, 5, 6, 7];
        end

        function ids = binaryPositiveIdsHuGaDB()
            ids = [1, 2, 3, 4, 6, 7, 9];
        end

        function names = binaryClassNames()
            names = {'Inactive', 'Active'};
        end

        function tf = isLocomotionNativeUSCHAD(classId)
            tf = ismember(classId, ActivityClassRegistry.binaryPositiveIdsUSCHAD());
        end

        function tf = isLocomotionNativeHuGaDB(classId)
            tf = ismember(classId, ActivityClassRegistry.binaryPositiveIdsHuGaDB());
        end

        function name = classNameUSCHAD(classId)
            if classId < 1 || classId > ActivityClassRegistry.USCHAD_N_CLASSES
                name = 'Unknown';
            else
                name = ActivityClassRegistry.USCHAD_CLASS_NAMES{classId};
            end
        end

        function name = classNameHuGaDB(classId)
            if classId < 1 || classId > ActivityClassRegistry.HUGADB_N_CLASSES
                name = 'Unknown';
            else
                name = ActivityClassRegistry.HUGADB_CLASS_NAMES{classId};
            end
        end

        function tok = hugadbFilenameTokenForClass(classId)
            % HuGaDB raw filenames use lowercase_snake_case activity slugs (GitHub layout).
            if classId < 1 || classId > ActivityClassRegistry.HUGADB_N_CLASSES || floor(classId) ~= classId
                tok = 'various';
                return;
            end
            toks = { ...
                'walking', 'running', 'going_up', 'going_down', ...
                'sitting', 'sitting_down', 'standing_up', 'standing', ...
                'bicycling', 'elevator_up', 'elevator_down', 'sitting_in_car' ...
                };
            tok = toks{classId};
        end
    end
end
