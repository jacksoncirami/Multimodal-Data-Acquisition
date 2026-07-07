%% 1. Configuration & Setup
clear; clc;

% UPDATE THIS: Path to your LSL library folder
addpath(genpath('C:\Users\hpuminds\Downloads\liblsl-Matlab-1.14.0-Win_amd64_R2020b\liblsl-Matlab'));

% Kinamoto/Bertec Network Settings
bertec_ip = '127.0.0.1';   % Localhost
bertec_port = 5000;        % Update if Kinamoto uses a different port

% Kinamoto/Bertec force plate channel order sent to LSL
% NOTE: Time_s is NOT included because LSL/XDF provides the real timestamps.
channel_names = { ...
    'AUX', 'SYNC', ...
    'FZR', 'MXR', 'MYR', ...
    'FZL', 'MXL', 'MYL', ...
    'FZ', 'MX', 'MY', ...
    'COPXR', 'COPYR', ...
    'COPXL', 'COPYL', ...
    'COPX', 'COPY'};

num_channels = numel(channel_names);   % 17 channels

% Expected sample rate
sample_rate = 1000;

% Stream identity for LabRecorder
stream_name = 'BertecForcePlate';
stream_type = 'Force';
source_id = 'Bertec_FP_01';

fprintf('Connecting to Kinamoto/Bertec stream at %s:%d...\n', bertec_ip, bertec_port);

try
    bertec_client = tcpclient(bertec_ip, bertec_port, 'Timeout', 10);
    fprintf('Connected to Kinamoto/Bertec TCP server.\n');
catch ME
    error(['Could not connect to Kinamoto/Bertec TCP server. ', ...
           'Make sure Kinamoto is open, live output is enabled, and the port is correct. ', ...
           'Original error: %s'], ME.message);
end

%% 2. Setup LSL Outlet

fprintf('\nLoading LSL library...\n');
lib = lsl_loadlib();

info = lsl_streaminfo( ...
    lib, ...
    stream_name, ...
    stream_type, ...
    num_channels, ...
    sample_rate, ...
    'cf_float32', ...
    source_id);

% Add channel labels to LSL metadata
channels = info.desc().append_child('channels');

for c = 1:num_channels
    ch = channels.append_child('channel');
    ch.append_child_value('label', channel_names{c});
    ch.append_child_value('type', stream_type);
    ch.append_child_value('unit', 'unknown');
end

outlet = lsl_outlet(info);

fprintf('\nLSL stream "%s" is broadcasting.\n', stream_name);
fprintf('Stream type: %s\n', stream_type);
fprintf('Channel count: %d\n', num_channels);
fprintf('Sample rate: %.1f Hz\n', sample_rate);

fprintf('\nChannel labels sent to LSL:\n');
for c = 1:num_channels
    fprintf('%2d: %s\n', c, channel_names{c});
end

fprintf('\nOpen LabRecorder, click Update, and confirm this stream appears.\n');

%% 3. Data Streaming Loop

stop_fig = figure( ...
    'Name', 'Stop Bertec LSL Stream', ...
    'KeyPressFcn', 'set(gcf,''Tag'',''stop'')', ...
    'Position', [100 100 380 120], ...
    'Menu', 'none', ...
    'ToolBar', 'none');

uicontrol( ...
    'Style', 'text', ...
    'String', 'Press ANY KEY in this window to stop streaming.', ...
    'Position', [30 40 320 40], ...
    'FontSize', 10);

disp('Streaming Kinamoto/Bertec data to LSL...');
disp('Keep this script running while LabRecorder records the .xdf file.');
disp('Select the popup window and press any key to stop.');

text_buffer = '';
sample_count = 0;
skipped_count = 0;
status_timer = tic;

try
    while ishandle(stop_fig) && ~strcmp(get(stop_fig, 'Tag'), 'stop')

        bytes_available = bertec_client.NumBytesAvailable;

        if bytes_available > 0
            raw_bytes = read(bertec_client, bytes_available, 'uint8');
            raw_bytes = uint8(raw_bytes(:)');

            text_buffer = [text_buffer, char(raw_bytes)];

            [rows, text_buffer] = parse_kinamoto_rows(text_buffer);

            for r = 1:length(rows)
                row = rows{r};

                % If Kinamoto sends 18 columns, assume column 1 is internal Time_s.
                % Drop it because LSL/XDF handles synchronization timestamps.
                if numel(row) == num_channels + 1
                    row = row(2:end);
                end

                % If Kinamoto sends exactly 17 columns, use them directly.
                if numel(row) == num_channels
                    sample = single(row(:));
                    outlet.push_sample(sample);
                    sample_count = sample_count + 1;
                else
                    skipped_count = skipped_count + 1;
                end
            end
        end

        if toc(status_timer) > 1
            fprintf('Bytes available: %d | Samples pushed to LSL: %d | Rows skipped: %d\n', ...
                bertec_client.NumBytesAvailable, sample_count, skipped_count);
            status_timer = tic;
        end

        pause(0.001);
    end

catch ME
    warning('Streaming interrupted: %s', ME.message);
end

%% 4. Cleanup

fprintf('\nClosing Kinamoto/Bertec stream...\n');
fprintf('Total samples pushed to LSL: %d\n', sample_count);
fprintf('Total rows skipped: %d\n', skipped_count);

if sample_count == 0
    warning(['No Bertec samples were pushed to LSL. ', ...
             'Kinamoto may be saving CSV data internally but not sending live TCP data to MATLAB. ', ...
             'Check the live/network output settings and port number.']);
end

clear bertec_client;

if exist('stop_fig', 'var') && ishandle(stop_fig)
    close(stop_fig);
end

disp('Kinamoto/Bertec LSL stream closed cleanly.');

%% ===== Local Helper Functions =====

function [rows, remainder] = parse_kinamoto_rows(buffer)
    rows = {};

    if isempty(buffer)
        remainder = '';
        return
    end

    % Normalize common separators
    buffer = strrep(buffer, ';', ',');

    % Split into lines
    line_parts = regexp(buffer, '\r\n|\n|\r', 'split');

    % Keep last line as remainder if it may be incomplete
    if buffer(end) == newline || buffer(end) == char(13)
        complete_lines = line_parts;
        remainder = '';
    else
        complete_lines = line_parts(1:end-1);
        remainder = line_parts{end};
    end

    for i = 1:length(complete_lines)
        line = strtrim(complete_lines{i});

        if isempty(line)
            continue
        end

        % Remove quotes
        line = strrep(line, '"', '');

        % Split by comma, tab, or spaces
        parts = regexp(line, '[,\t ]+', 'split');

        % Convert to numbers
        nums = str2double(parts);

        % Skip headers or non-numeric rows
        if isempty(nums) || any(isnan(nums))
            continue
        end

        rows{end+1} = nums(:); %#ok<AGROW>
    end
end
