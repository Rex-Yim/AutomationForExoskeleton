%% GenerateProjectTree.m
% --------------------------------------------------------------------------
% FUNCTION: [] = GenerateProjectTree()
% PURPOSE: Recursively scans the project directory and prints the folder/file structure to project_tree.txt.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-12
% LAST MODIFIED: 2025-12-15 (Fixed path logic to be location-independent)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
%   - MATLAB built-in functions (dir, fprintf, diary, fileparts, mfilename, mkdir)
% --------------------------------------------------------------------------
% NOTES:
%   - This version automatically determines the project root by locating the 
%     'scripts/utils' folder (where this script resides) and navigating two 
%     levels up.
%   - The script will work correctly no matter where it is called from, as 
%     long as it remains in 'scripts/utils/'.
%   - Excludes hidden folders (starting with '.').
%   - Truncates massive raw data folders (>200 files) for readability.
%   - Output is saved to: [Project Root]/scripts/utils/project_tree.txt
% --------------------------------------------------------------------------

% --- Define Paths (Location-Independent Logic) ---

% 1. Get the full path to the currently running script (ConcatenateCode.m)
% Note: mfilename('fullpath') works if the file is on the path or run directly.
this_script_path = mfilename('fullpath');
if isempty(this_script_path)
    error('Could not determine script path. Ensure it is saved and on the MATLAB path.');
end

% 2. Determine the project root by traversing up two levels from the script's folder:
%    /scripts/utils/ConcatenateCode.m -> /scripts/utils/ -> /scripts/ -> /AutomationForExoskeleton/
output_dir = fileparts(this_script_path);    % Gets the /scripts/utils/ folder
scripts_dir = fileparts(output_dir);         % Gets the /scripts/ folder
project_root = fileparts(scripts_dir);       % Gets the /AutomationForExoskeleton/ folder (the true project root)

% 3. Define the output file path (output_dir is already /scripts/utils/)
output_filename = 'project_tree.txt';
output_full_path = fullfile(output_dir, output_filename);

% Ensure the output directory exists
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
% ---------------------

% Line 1: Output only to Command Window (pre-execution message)
fprintf('Starting project structure generation...\n');

% 0. EXPLICIT OVERWRITE FIX: Delete the output file if it exists to guarantee a clean overwrite.
if exist(output_full_path, 'file')
    delete(output_full_path);
end

% 1. Start capturing the Command Window output to the specified file
diary(output_full_path);

try
    % Lines that are saved to the file:

    % Display the root name followed by '/'.
    [~, root_name, ~] = fileparts(project_root); % Get the name of the true project root
    fprintf('%s/\n', root_name);

    % 2. Start the recursive drawing process
    drawTreeLevel(project_root, ''); % Start scanning from the true project root
    
catch ME
    % Ensure diary is turned off even if an error occurs
    diary off;
    
    % Display error message to the console
    warning('An error occurred during script execution. Diary was turned off.');
    rethrow(ME);
end

% 3. Stop capturing the Command Window output
diary off;

% Line 2: Output only to Command Window (post-execution success message)
fprintf('\nScan completed and saved to %s.\n', output_full_path);

%% --- NESTED FUNCTION (The Recursive Logic) ---

function drawTreeLevel(current_path, prefix)
% Recursively draws the content of the current folder.

% 1. Get all entries (files and folders) in the current directory
listing = dir(current_path);

% 2. Filter system entries ('.', '..')
is_valid_entry = ~ismember({listing.name}, {'.', '..'});
entries = listing(is_valid_entry);

% 3. Filter hidden directories (starting with '.')
is_not_hidden = ~startsWith({entries.name}, '.');
entries = entries(is_not_hidden);

% 4. Split into subfolders and files, sort alphabetically
folders = entries([entries.isdir]);
files = entries(~[entries.isdir]);

[~, folder_idx] = sort({folders.name});
folders = folders(folder_idx);

[~, file_idx] = sort({files.name});
files = files(file_idx);

sorted_entries = [folders; files];

if isempty(sorted_entries)
    return;
end

N = length(sorted_entries);

% 5. Iterate and draw each entry
for i = 1:N
    entry = sorted_entries(i);
    is_last = (i == N);
    
    % --- Determine Connectors and Next Prefix Segment ---
    if is_last
        connector = '└── ';
        new_prefix_segment = '    '; 
    else
        connector = '├── ';
        new_prefix_segment = '│   '; 
    end
    
    % Build the full line to print
    name_suffix = entry.name;
    if entry.isdir
        name_suffix = [name_suffix, '/'];
    end
    
    fprintf('%s%s%s\n', prefix, connector, name_suffix);
    
    % 6. If the entry is a folder, recurse into it
    if entry.isdir
        new_path = fullfile(current_path, entry.name);
        new_prefix = [prefix, new_prefix_segment];

        % Truncation check for massive raw data folders (over 200 files)
        sub_listing = dir(new_path);
        sub_entries_count = length(sub_listing(~ismember({sub_listing.name}, {'.', '..'})));
        
        if sub_entries_count > 200 && contains(entry.name, 'raw', 'IgnoreCase', true)
            fprintf('%s%s%s\n', new_prefix, '└── ', '... (truncated: many raw data files)');
        else
            drawTreeLevel(new_path, new_prefix);
        end
    end
end
end