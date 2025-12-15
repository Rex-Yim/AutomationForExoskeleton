%% GenerateProjectTree.m
% --------------------------------------------------------------------------
% FUNCTION: GenerateProjectTree()
% PURPOSE : Generates a readable project directory tree and saves it to
%           scripts/utils/project_tree.txt
% FEATURES:
%   - Automatically finds project root regardless of current directory
%   - Shows first 3 items in folders with >10 contents
%   - Truncates large folders with "... (truncated: X more items)"
%   - Clean, properly aligned tree visualization
%   - Excludes hidden files/folders
% --------------------------------------------------------------------------
% AUTHOR     : Your Name
% CREATED    : 2025-12-12
% LAST UPDATE: 2025-12-16 (Fixed ternary operators, improved alignment)
% --------------------------------------------------------------------------

function GenerateProjectTree()

    % --- Determine paths (location-independent) ---
    this_script_path = mfilename('fullpath');
    if isempty(this_script_path)
        error('Cannot determine script path. Save the file and add to MATLAB path.');
    end

    utils_dir    = fileparts(this_script_path);           % scripts/utils/
    scripts_dir  = fileparts(utils_dir);                  % scripts/
    project_root = fileparts(scripts_dir);                % AutomationForExoskeleton/

    output_file  = fullfile(utils_dir, 'project_tree.txt');

    % --- Clean previous output ---
    if exist(output_file, 'file')
        delete(output_file);
    end

    fprintf('Starting project structure generation...\n');

    % --- Start capturing output to file ---
    diary(output_file);
    try
        [~, root_name] = fileparts(project_root);
        fprintf('%s/\n', root_name);

        drawTree(project_root, '');

    catch ME
        diary off;
        warning('Error during tree generation: %s', ME.message);
        rethrow(ME);
    end
    diary off;

    fprintf('Scan completed and saved to %s.\n', output_file);
end

%% --- Recursive Tree Drawing Function ---
function drawTree(current_path, prefix)

    % Get and filter directory contents
    listing = dir(current_path);
    is_valid = ~ismember({listing.name}, {'.', '..'});
    listing  = listing(is_valid);
    is_hidden = startsWith({listing.name}, '.');
    listing  = listing(~is_hidden);

    if isempty(listing)
        return;
    end

    % Separate and sort folders/files (case-insensitive)
    folders = listing([listing.isdir]);
    files   = listing(~[listing.isdir]);

    [~, idx_f] = sort(lower({folders.name}));
    [~, idx_i] = sort(lower({files.name}));

    folders = folders(idx_f);
    files   = files(idx_i);

    all_entries = [folders; files];
    N = length(all_entries);

    % Process each entry
    for i = 1:N
        entry   = all_entries(i);
        is_last = (i == N);

        % Determine connector and next prefix
        if is_last
            connector           = '└── ';
            next_prefix_segment = '    ';  % 4 spaces for alignment
        else
            connector           = '├── ';
            next_prefix_segment = '│   ';  % │ + 3 spaces
        end

        % Print current item
        name = entry.name;
        if entry.isdir
            name = [name, '/'];
        end
        fprintf('%s%s%s\n', prefix, connector, name);

        % If it's a folder, expand partially or fully
        if entry.isdir
            new_path   = fullfile(current_path, entry.name);
            new_prefix = [prefix, next_prefix_segment];

            % Count visible contents
            sub_list   = dir(new_path);
            sub_valid  = ~ismember({sub_list.name}, {'.', '..'});
            sub_hidden = startsWith({sub_list.name}, '.');
            sub_count  = sum(sub_valid & ~sub_hidden);

            if sub_count > 10
                % --- Show only first 3 items + truncation ---
                sub_entries = sub_list(sub_valid & ~sub_hidden);

                sub_folders = sub_entries([sub_entries.isdir]);
                sub_files   = sub_entries(~[sub_entries.isdir]);

                [~, sf_idx]  = sort(lower({sub_folders.name}));
                [~, sfi_idx] = sort(lower({sub_files.name}));

                sub_sorted = [sub_folders(sf_idx); sub_files(sfi_idx)];
                num_show   = min(3, length(sub_sorted));

                for k = 1:num_show
                    sub_entry = sub_sorted(k);
                    sub_name  = sub_entry.name;
                    if sub_entry.isdir
                        sub_name = [sub_name, '/'];
                    end

                    if k == num_show
                        sub_conn = '└── ';
                    else
                        sub_conn = '├── ';
                    end

                    fprintf('%s%s%s\n', new_prefix, sub_conn, sub_name);
                end

                remaining = sub_count - 3;
                if remaining > 0
                    fprintf('%s└── ... (truncated: %d more items)\n', new_prefix, remaining);
                end

            else
                % --- Show all contents (≤10 items) ---
                drawTree(new_path, new_prefix);
            end
        end
    end
end