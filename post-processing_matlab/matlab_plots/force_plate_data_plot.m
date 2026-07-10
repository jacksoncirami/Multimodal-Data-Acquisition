% ===== Adjustable settings =====
tStart = [];
tEnd   = [];
chToPlot = 1:size(ForcePlate_data,1);
maxPlotPoints = 20000;
showMarkerLabels = true;

% ===== Time window =====
if isempty(tStart)
    tStart = ForcePlate_time(1);
end

if isempty(tEnd)
    tEnd = ForcePlate_time(end);
end

idx = ForcePlate_time >= tStart & ForcePlate_time <= tEnd;

plotTime = ForcePlate_time(idx);
plotData = ForcePlate_data(chToPlot, idx);

% ===== Downsample for plotting only =====
step = max(1, ceil(length(plotTime) / maxPlotPoints));
plotTime = plotTime(1:step:end);
plotData = plotData(:, 1:step:end);

% ===== Normalize and offset channels for viewing =====
displayData = zeros(size(plotData));

for ch = 1:size(plotData,1)
    sig = plotData(ch,:);
    sig = sig - mean(sig, 'omitnan');
    scaleVal = max(abs(sig), [], 'omitnan');

    if isempty(scaleVal) || scaleVal == 0 || isnan(scaleVal)
        scaleVal = 1;
    end

    displayData(ch,:) = sig ./ scaleVal;
end

offsetAmount = 3;

figure('Name','Force Plate Data With Markers','NumberTitle','off');
hold on;

for ch = 1:size(displayData,1)
    yOffset = (size(displayData,1) - ch) * offsetAmount;
    plot(plotTime, displayData(ch,:) + yOffset);
end

% ===== Add markers and save marker handles =====
markerHandles = gobjects(0);

if exist('MarkerTable','var') && height(MarkerTable) > 0
    markerIdx = MarkerTable.Time_seconds >= tStart & MarkerTable.Time_seconds <= tEnd;
    markerTimes = MarkerTable.Time_seconds(markerIdx);
    markerLabels = string(MarkerTable.Marker_Label(markerIdx));

    for m = 1:length(markerTimes)
        hLine = xline(markerTimes(m), '--');
        markerHandles(end+1) = hLine;

        if showMarkerLabels
            hText = text(markerTimes(m), size(displayData,1)*offsetAmount, markerLabels(m), ...
                'Rotation', 90, ...
                'FontSize', 8, ...
                'HorizontalAlignment', 'right');
            markerHandles(end+1) = hText;
        end
    end
end

hold off;
grid on;
xlabel('Time (s)');
ylabel('Force plate channels, normalized and offset');
title('Force Plate Data With Markers');
xlim([tStart tEnd]);

% ===== Marker visibility checkbox =====
uicontrol('Style','checkbox', ...
    'String','Show markers', ...
    'Value',1, ...
    'Units','normalized', ...
    'Position',[0.82 0.94 0.15 0.04], ...
    'UserData',markerHandles, ...
    'Callback','h=get(gcbo,''UserData''); if get(gcbo,''Value''), set(h,''Visible'',''on''); else, set(h,''Visible'',''off''); end');
