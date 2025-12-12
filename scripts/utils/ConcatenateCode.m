%% ConcatenateCode.m
% --------------------------------------------------------------------------
% FUNCTION: [] = ConcatenateCode()
% PURPOSE: Generates a single, structured file (concatenated_code.txt) 
%          containing the source code of the entire project.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-12
% LAST MODIFIED: 2025-12-13
% --------------------------------------------------------------------------
% DEPENDENCIES: 
%   - MATLAB built-in file I/O and utility functions.
% --------------------------------------------------------------------------
% NOTES:
%   - Uses '###' headers for visibility and structure.
%   - Output is saved to the directory from which the script is executed.
%   - Uses dynamic path resolution for cross-platform compatibility.
% --------------------------------------------------------------------------

root_directory = pwd; 
output_filename = 'concatenated_code.txt';
% The output path is now set to the current directory (where the script is run)
% and the output filename.
output_full_path = fullfile(root_directory, output_filename);

fprintf('Starting code concatenation for copying...\n');

% Dynamically extract the project name from the current working directory's parent
% This assumes the user is running the script from the 'utils' folder, 
% and the project root is the parent folder.
[parent_dir, project_name, ~] = fileparts(fileparts(root_directory));
% Handle cases where 'pwd' might be the project root itself for robustness
if isempty(project_name) || strcmpi(project_name, root_directory)
    [~, project_name, ~] = fileparts(root_directory);
end
% Ensure the project name is clean
project_name = strrep(project_name, filesep, '');

% 1. Find all .m files recursively and filter hidden folders
% Search from the PARENT directory to capture all project files
search_root = fileparts(root_directory); 
search_path = fullfile(search_root, '**', '*.m');
listing = dir(search_path);

files_to_concatenate = [];
for i = 1:length(listing)
    full_path = fullfile(listing(i).folder, listing(i).name);
    
    % Get the path relative to the true project root
    rel_path = extractAfter(full_path, search_root);
    if startsWith(rel_path, filesep)
        rel_path = extractAfter(rel_path, filesep);
    end
    
    % Check if any part of the path starts with a '.' (e.g., .git/...)
    parts = strsplit(rel_path, filesep);
    if ~any(startsWith(parts, '.'))
        files_to_concatenate = [files_to_concatenate; listing(i)];
    end
end

if isempty(files_to_concatenate)
    fprintf('No .m files found in visible project directories.\n');
    return;
end

% --- CUSTOM SORTING: Ensure correct file order (Root files first, then subfolders by path) ---
files_to_sort = files_to_concatenate; 
% 1. Calculate the relative path for every file
relative_paths = cell(length(files_to_sort), 1);
for i = 1:length(files_to_sort)
    full_path_abs = fullfile(files_to_sort(i).folder, files_to_sort(i).name);
    
    % Get the path relative to the true project root for sorting
    rel_path = extractAfter(full_path_abs, search_root);
    if startsWith(rel_path, filesep)
        rel_path = extractAfter(rel_path, filesep);
    end
    
    % Add a special prefix to root files to force them to sort first
    if isempty(fileparts(rel_path))
        relative_paths{i} = ['!', rel_path]; 
    else
        relative_paths{i} = rel_path;
    end
end
% 2. Sort the files based on the relative path strings
[~, idx] = sort(relative_paths);
files_to_concatenate = files_to_sort(idx);
% --------------------------------------------------------------------------------------------

% 2. Open the output file for writing (will overwrite if it exists)
fileID = fopen(output_full_path, 'wt', 'n', 'UTF-8');
if fileID == -1
    error('Could not open file for writing: %s', output_full_path);
end

% 3. Process and print/write each file
fprintf('\n--- CONCATENATED CODE START ---\n\n');
% Write the global header to the file (only to file)
fprintf(fileID, '--- CONCATENATED CODE FROM PROJECT: %s ---\n\n', project_name);

for i = 1:length(files_to_concatenate)
    file_info = files_to_concatenate(i);
    
    full_path_abs = fullfile(file_info.folder, file_info.name);
    
    % Construct the desired 'FILE Path' using the dynamic project name and relative segment
    rel_path_segment = extractAfter(full_path_abs, search_root);
    if startsWith(rel_path_segment, filesep)
        rel_path_segment = extractAfter(rel_path_segment, filesep);
    end
    
    % The output path format is now: ProjectName/relative/path/to/file.m
    file_path_output = sprintf('%s/%s', project_name, rel_path_segment);
    
    % Read the content of the file
    file_content = fileread(full_path_abs);
    
    % --- Generate Custom Structured Header (USING 3 HASH SIGNS) ---
    header_start_line1 = sprintf('### START OF FILE: %s\n', file_info.name);
    header_start_line2 = sprintf('### FILE Path: %s\n', file_path_output);
    header_end = sprintf('### END OF FILE: %s\n\n', file_info.name);
    
    % Print structured output to Command Window
    fprintf(header_start_line1);
    fprintf(header_start_line2);
    fprintf('%s\n', file_content); 
    fprintf(header_end);
    
    % Write structured output to the text file
    fprintf(fileID, header_start_line1);
    fprintf(fileID, header_start_line2);
    fprintf(fileID, '%s\n', file_content);
    fprintf(fileID, header_end);
end

% 4. Close the file and finalize output
fclose(fileID);
fprintf('\n--- CONCATENATED CODE END ---\n');
fprintf('Content printed to terminal for immediate copy/paste.\n');
fprintf('A consolidated version has also been saved to: %s\n', output_full_path);