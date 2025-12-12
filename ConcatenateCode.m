%% ConcatenateCode.m
% --------------------------------------------------------------------------
% FUNCTION: [] = ConcatenateCode()
% PURPOSE: Generates a single, structured file (concatenated_code.txt) containing the source code of the entire project.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-12
% LAST MODIFIED: 2025-12-12
% --------------------------------------------------------------------------
% DEPENDENCIES: 
%   - MATLAB built-in file I/O and utility functions.
% --------------------------------------------------------------------------
% NOTES:
%   - Uses '###' headers to ensure visibility in the MATLAB Command Window.
%   - Hardcodes the base path prefix for file path standardization.
% --------------------------------------------------------------------------

root_directory = pwd; 
output_filename = 'concatenated_code.txt';

fprintf('Starting code concatenation for copying...\n');

% 1. Find all .m files recursively and filter hidden folders
search_path = fullfile(root_directory, '**', '*.m');
listing = dir(search_path);

files_to_concatenate = [];
for i = 1:length(listing)
    full_path = fullfile(listing(i).folder, listing(i).name);
    
    % Get the path relative to the root
    rel_path = extractAfter(full_path, root_directory);
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
    
    % Get the path relative to the root for sorting
    rel_path = extractAfter(full_path_abs, root_directory);
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
fileID = fopen(output_filename, 'wt', 'n', 'UTF-8');
if fileID == -1
    error('Could not open file for writing: %s', output_filename);
end

% 3. Process and print/write each file
fprintf('\n--- CONCATENATED CODE START ---\n\n');

% Write the global header to the file (only to file)
fprintf(fileID, '--- CONCATENATED CODE FROM PROJECT: %s ---\n\n', root_directory);

for i = 1:length(files_to_concatenate)
    file_info = files_to_concatenate(i);
    
    full_path_abs = fullfile(file_info.folder, file_info.name);
    
    % Construct the desired 'FILE Path' using the hardcoded prefix
    rel_path_segment = extractAfter(full_path_abs, root_directory);
    if startsWith(rel_path_segment, filesep)
        rel_path_segment = extractAfter(rel_path_segment, filesep);
    end
    % CRITICAL: Use the hardcoded prefix structure requested by the user
    file_path_output = sprintf('/Users/rexyim/Documents/MATLAB/AutomationForExoskeleton/%s', rel_path_segment);
    
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
fprintf('A consolidated version has also been saved to: %s\n', output_filename);