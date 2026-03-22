% MATLAB Script to Convert a CSV file into a .m script containing the data as a matrix.

% --- Housekeeping ---
clear;      % Clear all variables from the workspace
clc;        % Clear the command window
close all;  % Close all open figures

% --- Instructions ---
% 1. Make sure the 'CN_Baseline.csv' file is in the same directory as this script,
%    or provide the full, correct file path below.
% 2. Run this script.
% 3. A new file named 'CN_Baseline_data.m' will be created. This new file
%    will contain your data as a MATLAB matrix.

% --- Configuration ---
% Define the path to your input CSV file.
csv_filename = 'AllcountriesSD.csv';
%csv_filename = '/Users/frankiechen/Desktop/year2526_hkust/ECON4800/Data_25SUM/ADL/preprocessing/TryCA.csv';

% Define the name for the output .m script file
output_m_filename = 'AllcountriesSD.m';

% Define the variable name to be used in the output script
output_variable_name = 'NEW';


% --- Main Script ---
try
    % Use readmatrix to import the numerical data from the CSV.
    % It automatically skips the header row.
    disp(['Attempting to read numerical data from: ' csv_filename]);
    data_matrix = readmatrix(csv_filename);
    disp('Successfully read the numerical data.');

    % Open the new .m file for writing
    disp(['Creating and writing to ' output_m_filename '...']);
    fileID = fopen(output_m_filename, 'w');

    % Write a header comment and the variable definition
    fprintf(fileID, '%% Data automatically generated from %s on %s\n', csv_filename, datetime('now'));
    fprintf(fileID, '%s = [\n', output_variable_name);
    
    % Get the size of the matrix
    [rows, cols] = size(data_matrix);

    % Loop through each row and column to write the data
    for i = 1:rows
        for j = 1:cols
            value = data_matrix(i, j);
            if isnan(value)
                fprintf(fileID, 'NaN');
            else
                % Use a format specifier that preserves precision
                fprintf(fileID, '%.15g', value);
            end
            
            % Add a tab for spacing, but not after the last element in a row
            if j < cols
                fprintf(fileID, '\t');
            end
        end
        % Add a new line after each row
        fprintf(fileID, '\n');
    end

    % Write the closing bracket and semicolon
    fprintf(fileID, '];\n');
    
    % Close the file
    fclose(fileID);

    disp('Conversion complete!');
    fprintf('WOOHOO!!! A new script file named "%s" has been created.\n', output_m_filename);
    disp('You can now run this new script to load the data into your workspace.');

catch ME
    % Display an error message if the file is not found or another error occurs
    if (strcmp(ME.identifier, 'MATLAB:readtable:FileNotFound') || strcmp(ME.identifier, 'MATLAB:readmatrix:FileNotFound'))
        fprintf(2, 'Error: The file was not found.\n');
        fprintf(2, 'Please make sure that "%s" is in the correct path.\n', csv_filename);
    else
        % Display any other errors that might occur
        rethrow(ME);
    end
end

