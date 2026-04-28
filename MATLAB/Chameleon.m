classdef Chameleon < matlab.apps.AppBase

    % =====================================================================
    %  Chameleon  –  Batch Stain Normalizer for RGB Histology Images
    %  Supports H&E, IHC, and general brightfield images.
    %
    %  Four normalization modes:
    %    1. Histogram matching  → user reference image
    %    2. Histogram matching  → batch-average CDF
    %    3. Reinhard            → user reference image
    %    4. Reinhard            → batch-average synthetic reference
    %
    %  Pre-flight Inspector:
    %    Preview all 4 methods on any image in the batch before committing.
    %    Original shown small on left; 2×2 grid of normalised results on right.
    %    Step through the entire batch, then pick a method and close.
    %
    %  Outputs:
    %    • Normalised image files saved to output folder
    %    • CSV log of per-image normalization statistics
    % =====================================================================

    % =====================================================================
    %  PROPERTIES
    % =====================================================================
    properties (Access = public)
        UIFigure              matlab.ui.Figure

        % Layout
        HeaderPanel           matlab.ui.container.Panel
        LeftPanel             matlab.ui.container.Panel
        RightPanel            matlab.ui.container.Panel
        StatusPanel           matlab.ui.container.Panel

        % Header
        TitleLabel            matlab.ui.control.Label
        SubtitleLabel         matlab.ui.control.Label

        % Mode selection
        ModeLabel             matlab.ui.control.Label
        ModeButtonGroup       matlab.ui.container.ButtonGroup
        Mode1Button           matlab.ui.control.RadioButton
        Mode2Button           matlab.ui.control.RadioButton
        Mode3Button           matlab.ui.control.RadioButton
        Mode4Button           matlab.ui.control.RadioButton

        % Mode description
        ModeDescPanel         matlab.ui.container.Panel
        ModeDescLabel         matlab.ui.control.Label

        % Input folder
        InputLabel            matlab.ui.control.Label
        InputPathField        matlab.ui.control.EditField
        BrowseInputButton     matlab.ui.control.Button

        % Reference image
        RefImageLabel         matlab.ui.control.Label
        RefImageField         matlab.ui.control.EditField
        BrowseRefButton       matlab.ui.control.Button

        % Output folder
        OutputLabel           matlab.ui.control.Label
        OutputPathField       matlab.ui.control.EditField
        BrowseOutputButton    matlab.ui.control.Button

        % Options
        OptionsLabel          matlab.ui.control.Label
        FormatDropDownLabel   matlab.ui.control.Label
        FormatDropDown        matlab.ui.control.DropDown
        SaveLogCheckBox       matlab.ui.control.CheckBox
        PreviewCheckBox       matlab.ui.control.CheckBox

        % File list
        FileListLabel         matlab.ui.control.Label
        FileListBox           matlab.ui.control.ListBox
        FileCountLabel        matlab.ui.control.Label
        LoadFilesButton       matlab.ui.control.Button
        ClearFilesButton      matlab.ui.control.Button

        % Action buttons
        RunButton             matlab.ui.control.Button
        CancelButton          matlab.ui.control.Button
        PreviewBatchButton    matlab.ui.control.Button

        % Progress
        ProgressLabel         matlab.ui.control.Label
        StatusLabel           matlab.ui.control.Label

        % Standard live preview (shown during batch run)
        PreviewLabel          matlab.ui.control.Label
        AxesOriginal          matlab.ui.control.UIAxes
        AxesNormalized        matlab.ui.control.UIAxes
        AxesHistOrig          matlab.ui.control.UIAxes
        AxesHistNorm          matlab.ui.control.UIAxes
        OriginalLabel         matlab.ui.control.Label
        NormalizedLabel       matlab.ui.control.Label
        HistOrigLabel         matlab.ui.control.Label
        HistNormLabel         matlab.ui.control.Label

        % ── Pre-flight Inspector ───────────────────────────────────────
        InspectorPanel        matlab.ui.container.Panel
        % Navigation / controls
        InspTitleLabel        matlab.ui.control.Label
        InspImageLabel        matlab.ui.control.Label
        InspPrevButton        matlab.ui.control.Button
        InspNextButton        matlab.ui.control.Button
        InspUseMethodDDLabel  matlab.ui.control.Label
        InspUseMethodDD       matlab.ui.control.DropDown
        InspApplyButton       matlab.ui.control.Button
        InspCloseButton       matlab.ui.control.Button
        InspStatusLabel       matlab.ui.control.Label
        % Original image (small, left column)
        InspAxOrig            matlab.ui.control.UIAxes
        InspLblOrig           matlab.ui.control.Label
        % 2×2 grid of normalised results
        InspAxM1              matlab.ui.control.UIAxes   % top-left:  Mode 1
        InspAxM2              matlab.ui.control.UIAxes   % top-right: Mode 2
        InspAxM3              matlab.ui.control.UIAxes   % bot-left:  Mode 3
        InspAxM4              matlab.ui.control.UIAxes   % bot-right: Mode 4
        InspLblM1             matlab.ui.control.Label
        InspLblM2             matlab.ui.control.Label
        InspLblM3             matlab.ui.control.Label
        InspLblM4             matlab.ui.control.Label
    end

    properties (Access = private)
        ImageFiles      cell
        CancelFlag      logical
        InspectorIndex  double = 1
    end

    properties (Constant, Access = private)
        AppColors = struct( ...
            'bg',       [0.08 0.10 0.14], ...
            'panel',    [0.12 0.15 0.20], ...
            'accent',   [0.18 0.52 0.80], ...
            'accentAlt',[0.22 0.70 0.55], ...
            'text',     [0.92 0.93 0.95], ...
            'textDim',  [0.55 0.60 0.68], ...
            'warning',  [0.95 0.65 0.20], ...
            'success',  [0.25 0.78 0.48], ...
            'danger',   [0.90 0.33 0.33])
        ModeDescriptions = { ...
            'Histogram Matching → Reference Image:  Match each image''s full RGB distribution to a single chosen reference slide. Best when you have a high-quality reference with ideal staining.', ...
            'Histogram Matching → Batch Average:  Build a theoretical mean histogram across all images, then match every image to that population average. No reference image needed.', ...
            'Reinhard → Reference Image:  Transfer LAB color statistics (mean + std per channel) from a reference image to each source. More conservative than histogram matching; lower artifact risk.', ...
            'Reinhard → Batch-Average Synthetic Reference:  Compute mean LAB statistics across the entire batch to build a bias-free synthetic reference, then apply Reinhard normalization to all images.' ...
        }
    end

    % =====================================================================
    %  STARTUP
    % =====================================================================
    methods (Access = private)

        function startupFcn(app)
            app.CancelFlag     = false;
            app.ImageFiles     = {};
            app.InspectorIndex = 1;
            applyTheme(app);
            updateModeUI(app);
            updateStatus(app, 'Ready  –  select a mode and load images to begin.', 'dim');
        end

    end

    % =====================================================================
    %  CALLBACKS
    % =====================================================================
    methods (Access = private)

        function ModeButtonGroupSelectionChanged(app, ~)
            updateModeUI(app);
        end

        function BrowseInputButtonPushed(app, ~)
            folder = uigetdir(app.InputPathField.Value, 'Select Input Image Folder');
            if folder ~= 0
                app.InputPathField.Value = folder;
                loadImagesFromFolder(app, folder);
            end
        end

        function BrowseRefButtonPushed(app, ~)
            [f, p] = uigetfile( ...
                {'*.tif;*.tiff;*.jpg;*.jpeg;*.bmp','Image Files (*.tif, *.tiff, *.jpg, *.jpeg, *.bmp)'}, ...
                'Select Reference Image', app.InputPathField.Value);
            if f ~= 0
                app.RefImageField.Value = fullfile(p, f);
            end
        end

        function BrowseOutputButtonPushed(app, ~)
            folder = uigetdir(app.OutputPathField.Value, 'Select Output Folder');
            if folder ~= 0, app.OutputPathField.Value = folder; end
        end

        function LoadFilesButtonPushed(app, ~)
            folder = app.InputPathField.Value;
            if isempty(folder) || ~isfolder(folder)
                uialert(app.UIFigure,'Please enter a valid input folder.','Invalid Folder','Icon','warning');
                return
            end
            loadImagesFromFolder(app, folder);
        end

        function ClearFilesButtonPushed(app, ~)
            app.ImageFiles = {};
            app.FileListBox.Items   = {};
            app.FileCountLabel.Text = '0 images loaded';
            clearPreview(app);
            updateStatus(app, 'File list cleared.', 'dim');
        end

        function FileListBoxValueChanged(app, ~)
            if ~app.PreviewCheckBox.Value, return; end
            idx = find(strcmp(app.FileListBox.Items, app.FileListBox.Value), 1);
            if isempty(idx), return; end
            showPreviewImage(app, app.ImageFiles{idx});
        end

        function RunButtonPushed(app, ~)
            if ~validateInputs(app), return; end
            app.CancelFlag = false;
            app.RunButton.Enable    = 'off';
            app.CancelButton.Enable = 'on';
            try
                runNormalization(app);
            catch ME
                uialert(app.UIFigure, ME.message, 'Error', 'Icon','error');
                updateStatus(app, ['Error: ' ME.message], 'danger');
            end
            app.RunButton.Enable    = 'on';
            app.CancelButton.Enable = 'off';
        end

        function CancelButtonPushed(app, ~)
            app.CancelFlag = true;
            updateStatus(app, 'Cancelling after current image…', 'warning');
        end

        % ── Inspector callbacks ────────────────────────────────────────
        function PreviewBatchButtonPushed(app, ~)
            if isempty(app.ImageFiles)
                uialert(app.UIFigure,'Please load images first.','No Images','Icon','warning');
                return
            end
            app.InspectorIndex = 1;
            app.InspectorPanel.Visible = 'on';
            runInspectorForIndex(app, 1);
        end

        function InspPrevButtonPushed(app, ~)
            if app.InspectorIndex > 1
                app.InspectorIndex = app.InspectorIndex - 1;
                runInspectorForIndex(app, app.InspectorIndex);
            end
        end

        function InspNextButtonPushed(app, ~)
            if app.InspectorIndex < numel(app.ImageFiles)
                app.InspectorIndex = app.InspectorIndex + 1;
                runInspectorForIndex(app, app.InspectorIndex);
            end
        end

        function InspApplyButtonPushed(app, ~)
            switch app.InspUseMethodDD.Value
                case 'Mode 1 – Hist Match, Reference',  app.Mode1Button.Value = true;
                case 'Mode 2 – Hist Match, Batch Avg',  app.Mode2Button.Value = true;
                case 'Mode 3 – Reinhard, Reference',    app.Mode3Button.Value = true;
                case 'Mode 4 – Reinhard, Batch Avg',    app.Mode4Button.Value = true;
            end
            updateModeUI(app);
            app.InspectorPanel.Visible = 'off';
            updateStatus(app, sprintf('Method set to: %s', app.InspUseMethodDD.Value), 'success');
        end

        function InspCloseButtonPushed(app, ~)
            app.InspectorPanel.Visible = 'off';
        end

    end % callbacks

    % =====================================================================
    %  CORE LOGIC
    % =====================================================================
    methods (Access = private)

        % ── Load images ───────────────────────────────────────────────
        function loadImagesFromFolder(app, folder)
            d     = dir(fullfile(folder, '*.*'));
            d     = d(~[d.isdir]);
            valid = {'.tif','.tiff','.jpg','.jpeg','.bmp'};
            files = {};
            for k = 1:numel(d)
                [~,~,ext] = fileparts(d(k).name);
                if any(strcmpi(ext, valid))
                    files{end+1} = fullfile(d(k).folder, d(k).name); %#ok<AGROW>
                end
            end
            if isempty(files)
                uialert(app.UIFigure, ...
                    sprintf('No supported images found in:\n%s\n\nFormats: TIF, TIFF, JPG, JPEG, BMP', folder), ...
                    'No Images','Icon','warning');
                return
            end
            app.ImageFiles = files;
            app.FileListBox.Items   = cellfun(@getFileName, files, 'UniformOutput', false);
            app.FileCountLabel.Text = sprintf('%d image(s) loaded', numel(files));
            updateStatus(app, sprintf('Loaded %d images.', numel(files)), 'success');
        end

        % ── Validate ──────────────────────────────────────────────────
        function ok = validateInputs(app)
            ok = false;
            if isempty(app.ImageFiles)
                uialert(app.UIFigure,'No images loaded.','No Images','Icon','warning'); return
            end
            if app.Mode1Button.Value || app.Mode3Button.Value
                ref = app.RefImageField.Value;
                if isempty(ref) || ~isfile(ref)
                    uialert(app.UIFigure,'Please select a valid reference image.','Missing Reference','Icon','warning'); return
                end
            end
            outDir = app.OutputPathField.Value;
            if isempty(outDir)
                uialert(app.UIFigure,'Please specify an output folder.','No Output Folder','Icon','warning'); return
            end
            if ~isfolder(outDir)
                try; mkdir(outDir);
                catch
                    uialert(app.UIFigure,'Cannot create output folder.','Folder Error','Icon','error'); return
                end
            end
            ok = true;
        end

        % ── Main dispatcher ───────────────────────────────────────────
        function runNormalization(app)
            outDir  = app.OutputPathField.Value;
            fmt     = lower(app.FormatDropDown.Value);
            quality = 100;
            doLog   = app.SaveLogCheckBox.Value;

            if app.Mode1Button.Value
                updateStatus(app,'Mode 1: Histogram matching to reference…','accent');
                tgtCDF = computeCDF(ensureUint8RGB(imread(app.RefImageField.Value)));
                runHistogramBatch(app, tgtCDF, outDir, fmt, quality, doLog, 'HistMatch-Reference');

            elseif app.Mode2Button.Value
                updateStatus(app,'Mode 2: Computing batch-average histogram…','accent');
                tgtCDF = computeBatchAvgCDF(app, 0, 100);
                if isempty(tgtCDF), return; end
                runHistogramBatch(app, tgtCDF, outDir, fmt, quality, doLog, 'HistMatch-BatchAvg');

            elseif app.Mode3Button.Value
                updateStatus(app,'Mode 3: Reinhard to reference image…','accent');
                tgtStats = computeReinhardStats(ensureUint8RGB(imread(app.RefImageField.Value)));
                runReinhardBatch(app, tgtStats, outDir, fmt, quality, doLog, 'Reinhard-Reference');

            elseif app.Mode4Button.Value
                updateStatus(app,'Mode 4: Computing batch-average LAB statistics…','accent');
                tgtStats = computeBatchAvgReinhardStats(app, 0, 100);
                if isempty(tgtStats), return; end
                runReinhardBatch(app, tgtStats, outDir, fmt, quality, doLog, 'Reinhard-BatchAvg');
            end
        end

        % ── Histogram batch ───────────────────────────────────────────
        function runHistogramBatch(app, tgtCDF, outDir, fmt, quality, doLog, modeName)
            nFiles = numel(app.ImageFiles);
            logData = {}; cNames = {'R','G','B'};
            logHdr  = {'Filename','Channel','OrigMean','OrigStd','NormMean','NormStd','WassersteinDist'};

            for i = 1:nFiles
                if app.CancelFlag, updateStatus(app,'Cancelled.','warning'); return; end
                setProgress(app, (i-1)/nFiles*100, sprintf('Processing %d / %d', i, nFiles));
                updateStatus(app, sprintf('Normalising: %s', getFileName(app.ImageFiles{i})), 'accent');
                drawnow

                try; img = ensureUint8RGB(imread(app.ImageFiles{i})); catch; continue; end
                imgNorm = img;

                for ch = 1:3
                    orig = img(:,:,ch);
                    nc   = histogramMatch(orig, computeCDFChannel(orig), tgtCDF(:,ch));
                    imgNorm(:,:,ch) = nc;
                    if doLog
                        wd = wassersteinDist(double(orig(:))/255, double(nc(:))/255);
                        logData(end+1,:) = {getFileName(app.ImageFiles{i}), cNames{ch}, ...
                            mean(double(orig(:))), std(double(orig(:))), ...
                            mean(double(nc(:))), std(double(nc(:))), wd}; %#ok<AGROW>
                    end
                end

                [~,b,~] = fileparts(app.ImageFiles{i});
                saveImage(imgNorm, fullfile(outDir,[b '_norm.' fmt]), fmt, quality);
                if app.PreviewCheckBox.Value, showProcessedPreview(app, img, imgNorm, modeName); end
            end

            setProgress(app, 100, 'Complete');
            if doLog && ~isempty(logData), writeCSVLog(outDir, logData, logHdr, modeName); end
            updateStatus(app, sprintf('Done! %d images → %s', nFiles, outDir), 'success');
            uialert(app.UIFigure, sprintf('%d images normalised.\nOutput: %s', nFiles, outDir), ...
                    'Complete','Icon','success');
        end

        % ── Reinhard batch ────────────────────────────────────────────
        function runReinhardBatch(app, tgtStats, outDir, fmt, quality, doLog, modeName)
            nFiles = numel(app.ImageFiles);
            logData = {}; cNames = {'L','a','b'};
            logHdr  = {'Filename','Channel','OrigMean_LAB','OrigStd_LAB','NormMean_LAB','NormStd_LAB','DeltaE_mean'};

            for i = 1:nFiles
                if app.CancelFlag, updateStatus(app,'Cancelled.','warning'); return; end
                setProgress(app, (i-1)/nFiles*100, sprintf('Processing %d / %d', i, nFiles));
                updateStatus(app, sprintf('Reinhard: %s', getFileName(app.ImageFiles{i})), 'accent');
                drawnow

                try; img = ensureUint8RGB(imread(app.ImageFiles{i})); catch; continue; end
                [imgNorm, srcStats] = reinhardNormalize(img, tgtStats);

                if doLog
                    labO = rgb2lab(img); labN = rgb2lab(imgNorm);
                    nStats = computeReinhardStats(imgNorm);
                    for ch = 1:3
                        dE = mean(abs(labN(:,:,ch) - labO(:,:,ch)), 'all');
                        logData(end+1,:) = {getFileName(app.ImageFiles{i}), cNames{ch}, ...
                            srcStats.mu(ch), srcStats.sigma(ch), ...
                            nStats.mu(ch), nStats.sigma(ch), dE}; %#ok<AGROW>
                    end
                end

                [~,b,~] = fileparts(app.ImageFiles{i});
                saveImage(imgNorm, fullfile(outDir,[b '_norm.' fmt]), fmt, quality);
                if app.PreviewCheckBox.Value, showProcessedPreview(app, img, imgNorm, modeName); end
            end

            setProgress(app, 100, 'Complete');
            if doLog && ~isempty(logData), writeCSVLog(outDir, logData, logHdr, modeName); end
            updateStatus(app, sprintf('Done! %d images → %s', nFiles, outDir), 'success');
            uialert(app.UIFigure, sprintf('%d images normalised.\nOutput: %s', nFiles, outDir), ...
                    'Complete','Icon','success');
        end

        % ── Batch stat helpers ────────────────────────────────────────
        function tgtCDF = computeBatchAvgCDF(app, p0, p1)
            nFiles = numel(app.ImageFiles);
            sumH = zeros(256,3); n = 0;
            for i = 1:nFiles
                if app.CancelFlag, tgtCDF = []; return; end
                setProgress(app, p0+(i-1)/nFiles*(p1-p0), sprintf('Analysing %d/%d',i,nFiles)); drawnow
                try
                    img = ensureUint8RGB(imread(app.ImageFiles{i}));
                    for ch = 1:3, sumH(:,ch) = sumH(:,ch) + imhist(img(:,:,ch),256); end
                    n = n+1;
                catch; end
            end
            if n == 0
                uialert(app.UIFigure,'No readable images.','Error','Icon','error');
                tgtCDF = []; return
            end
            avg = sumH/n; tgtCDF = zeros(256,3);
            for ch = 1:3, tgtCDF(:,ch) = cumsum(avg(:,ch))/sum(avg(:,ch)); end
        end

        function tgtStats = computeBatchAvgReinhardStats(app, p0, p1)
            nFiles = numel(app.ImageFiles);
            sumMu = zeros(1,3); sumSig = zeros(1,3); n = 0;
            for i = 1:nFiles
                if app.CancelFlag, tgtStats = []; return; end
                setProgress(app, p0+(i-1)/nFiles*(p1-p0), sprintf('Analysing LAB %d/%d',i,nFiles)); drawnow
                try
                    s = computeReinhardStats(ensureUint8RGB(imread(app.ImageFiles{i})));
                    sumMu = sumMu+s.mu; sumSig = sumSig+s.sigma; n = n+1;
                catch; end
            end
            if n == 0
                uialert(app.UIFigure,'No readable images.','Error','Icon','error');
                tgtStats = []; return
            end
            tgtStats.mu = sumMu/n; tgtStats.sigma = sumSig/n;
        end

        % ── Inspector logic ───────────────────────────────────────────
        function runInspectorForIndex(app, idx)
            c      = app.AppColors;
            nFiles = numel(app.ImageFiles);
            app.InspImageLabel.Text   = sprintf('Image %d of %d  —  %s', idx, nFiles, getFileName(app.ImageFiles{idx}));
            app.InspPrevButton.Enable = matlab.lang.OnOffSwitchState(idx > 1);
            app.InspNextButton.Enable = matlab.lang.OnOffSwitchState(idx < nFiles);
            app.InspStatusLabel.Text  = 'Loading…';
            drawnow

            % Clear all axes
            for ax = {app.InspAxOrig, app.InspAxM1, app.InspAxM2, app.InspAxM3, app.InspAxM4}
                cla(ax{1}); ax{1}.Title.String = '';
            end

            % Load source image
            try
                img = ensureUint8RGB(imread(app.ImageFiles{idx}));
            catch ME
                app.InspStatusLabel.Text = ['Could not read: ' ME.message];
                return
            end

            % Show original
            imshow(img,'Parent',app.InspAxOrig);
            styleInspAxes(app.InspAxOrig,'Original',c.textDim);
            drawnow

            % ── Modes 2 & 4: batch-average (no reference needed) ──────
            app.InspStatusLabel.Text = 'Computing batch-average histogram (Mode 2)…'; drawnow
            tgtCDF = computeBatchAvgCDF(app, 0, 50);

            if ~isempty(tgtCDF)
                imgM2 = img;
                for ch = 1:3
                    imgM2(:,:,ch) = histogramMatch(img(:,:,ch), ...
                        computeCDFChannel(img(:,:,ch)), tgtCDF(:,ch));
                end
                imshow(imgM2,'Parent',app.InspAxM2);
                styleInspAxes(app.InspAxM2,'Mode 2 – Hist Match, Batch Avg',c.accent);
            end
            drawnow

            app.InspStatusLabel.Text = 'Computing batch-average Reinhard (Mode 4)…'; drawnow
            tgtStats = computeBatchAvgReinhardStats(app, 50, 100);

            if ~isempty(tgtStats)
                imgM4 = reinhardNormalize(img, tgtStats);
                imshow(imgM4,'Parent',app.InspAxM4);
                styleInspAxes(app.InspAxM4,'Mode 4 – Reinhard, Batch Avg',c.accentAlt);
            end
            drawnow

            % ── Modes 1 & 3: reference-based ──────────────────────────
            refPath = app.RefImageField.Value;
            if ~isempty(refPath) && isfile(refPath)
                app.InspStatusLabel.Text = 'Computing reference-based methods (Modes 1 & 3)…'; drawnow
                try
                    refImg   = ensureUint8RGB(imread(refPath));
                    refCDF   = computeCDF(refImg);
                    refStats = computeReinhardStats(refImg);

                    imgM1 = img;
                    for ch = 1:3
                        imgM1(:,:,ch) = histogramMatch(img(:,:,ch), ...
                            computeCDFChannel(img(:,:,ch)), refCDF(:,ch));
                    end
                    imshow(imgM1,'Parent',app.InspAxM1);
                    styleInspAxes(app.InspAxM1,'Mode 1 – Hist Match, Reference',c.accent);

                    imgM3 = reinhardNormalize(img, refStats);
                    imshow(imgM3,'Parent',app.InspAxM3);
                    styleInspAxes(app.InspAxM3,'Mode 3 – Reinhard, Reference',c.accentAlt);
                catch ME
                    noRefMsg(app.InspAxM1, 'Mode 1 – error reading reference', c);
                    noRefMsg(app.InspAxM3, 'Mode 3 – error reading reference', c);
                    warning('Inspector:refError','%s',ME.message);
                end
            else
                noRefMsg(app.InspAxM1, 'Mode 1 – no reference set', c);
                noRefMsg(app.InspAxM3, 'Mode 3 – no reference set', c);
            end

            app.InspStatusLabel.Text = sprintf('Image %d of %d  —  use ◀ ▶ to step through batch', idx, nFiles);
            drawnow
        end

        % ── Live run preview ──────────────────────────────────────────
        function showPreviewImage(app, filepath)
            try
                img = ensureUint8RGB(imread(filepath));
                imshow(img,'Parent',app.AxesOriginal);
                plotRGBHist(app.AxesHistOrig, img, app.AppColors);
                styleHistAxes(app.AxesHistOrig,'Original Histogram',app.AppColors);
                cla(app.AxesNormalized); cla(app.AxesHistNorm);
            catch; end
        end

        function showProcessedPreview(app, origImg, normImg, modeName)
            imshow(origImg,'Parent',app.AxesOriginal);
            imshow(normImg,'Parent',app.AxesNormalized);
            app.AxesOriginal.Title.String   = 'Original';
            app.AxesNormalized.Title.String = modeName;
            app.AxesOriginal.Title.Color    = app.AppColors.text;
            app.AxesNormalized.Title.Color  = app.AppColors.accent;
            plotRGBHist(app.AxesHistOrig, origImg, app.AppColors);
            plotRGBHist(app.AxesHistNorm, normImg, app.AppColors);
            styleHistAxes(app.AxesHistOrig,'Original Histogram',app.AppColors);
            styleHistAxes(app.AxesHistNorm,'Normalised Histogram',app.AppColors);
            drawnow
        end

        function clearPreview(app)
            cla(app.AxesOriginal); cla(app.AxesNormalized);
            cla(app.AxesHistOrig); cla(app.AxesHistNorm);
        end

        % ── Mode UI update ────────────────────────────────────────────
        function updateModeUI(app)
            modeIdx = find([app.Mode1Button.Value, app.Mode2Button.Value, ...
                            app.Mode3Button.Value, app.Mode4Button.Value], 1);
            if isempty(modeIdx), modeIdx = 1; end
            app.ModeDescLabel.Text = app.ModeDescriptions{modeIdx};

            needsRef = (modeIdx == 1 || modeIdx == 3);
            onOff    = matlab.lang.OnOffSwitchState(needsRef);
            app.RefImageLabel.Enable   = onOff;
            app.RefImageField.Enable   = onOff;
            app.BrowseRefButton.Enable = onOff;
            app.RunButton.BackgroundColor = app.AppColors.accent;
            app.RunButton.Text            = '▶  Run Normalization';
        end

        % ── Theme ─────────────────────────────────────────────────────
        function applyTheme(app)
            c = app.AppColors;
            app.UIFigure.Color = c.bg;
            for p = {app.HeaderPanel,app.LeftPanel,app.RightPanel, ...
                     app.StatusPanel,app.ModeDescPanel,app.InspectorPanel}
                try; p{1}.BackgroundColor = c.panel; catch; end
            end
            app.InspectorPanel.BackgroundColor = c.bg;

            allLbls = {app.TitleLabel,app.SubtitleLabel,app.ModeLabel, ...
                app.InputLabel,app.RefImageLabel,app.OutputLabel, ...
                app.OptionsLabel,app.FormatDropDownLabel, ...
                app.FileListLabel,app.FileCountLabel, ...
                app.PreviewLabel,app.OriginalLabel,app.NormalizedLabel, ...
                app.HistOrigLabel,app.HistNormLabel,app.ModeDescLabel, ...
                app.InspTitleLabel,app.InspImageLabel,app.InspStatusLabel, ...
                app.InspUseMethodDDLabel, ...
                app.InspLblOrig,app.InspLblM1,app.InspLblM2,app.InspLblM3,app.InspLblM4};
            for k = 1:numel(allLbls)
                try; allLbls{k}.FontColor=c.text; allLbls{k}.BackgroundColor='none'; catch; end
            end
            app.TitleLabel.FontColor    = c.accent;
            app.SubtitleLabel.FontColor = c.textDim;
            app.ModeDescLabel.FontColor = c.textDim;
            app.InspTitleLabel.FontColor = c.accentAlt;
            app.InspImageLabel.FontColor = c.textDim;
            app.InspStatusLabel.FontColor = c.textDim;
            app.InspLblM1.FontColor = c.accent;
            app.InspLblM2.FontColor = c.accent;
            app.InspLblM3.FontColor = c.accentAlt;
            app.InspLblM4.FontColor = c.accentAlt;
            app.InspLblOrig.FontColor = c.textDim;

            for ax = {app.AxesOriginal,app.AxesNormalized,app.AxesHistOrig,app.AxesHistNorm, ...
                      app.InspAxOrig,app.InspAxM1,app.InspAxM2,app.InspAxM3,app.InspAxM4}
                try
                    ax{1}.Color=c.bg; ax{1}.XColor=c.textDim;
                    ax{1}.YColor=c.textDim; ax{1}.Title.Color=c.textDim;
                catch; end
            end
            app.RunButton.BackgroundColor    = c.accent;
            app.RunButton.FontColor          = [1 1 1];
            app.RunButton.FontWeight         = 'bold';
            app.CancelButton.BackgroundColor = c.danger;
            app.CancelButton.FontColor       = [1 1 1];
        end

        function setProgress(app, ~, msg)
            app.ProgressLabel.Text = msg;
        end

        function updateStatus(app, msg, level)
            c = app.AppColors;
            switch level
                case 'success', col=c.success;
                case 'warning', col=c.warning;
                case 'danger',  col=c.danger;
                case 'accent',  col=c.accent;
                otherwise,      col=c.textDim;
            end
            app.StatusLabel.Text      = msg;
            app.StatusLabel.FontColor = col;
        end

    end % private methods

    % =====================================================================
    %  UI CONSTRUCTION
    % =====================================================================
    methods (Access = private)

        function createComponents(app)
            c = app.AppColors;
            W = 1340; H = 870;

            % ── Figure ────────────────────────────────────────────────
            app.UIFigure = uifigure('Visible','off','Position',[60 60 W H], ...
                'Name','Chameleon  v1.0','Color',c.bg);

            % ── Header ────────────────────────────────────────────────
            app.HeaderPanel = uipanel(app.UIFigure,'Position',[0 H-72 W 72], ...
                'BackgroundColor',c.panel,'BorderType','none');
            app.TitleLabel = uilabel(app.HeaderPanel,'Position',[20 20 600 36], ...
                'Text','Chameleon','FontSize',22,'FontWeight','bold','FontColor',c.accent);
            app.SubtitleLabel = uilabel(app.HeaderPanel,'Position',[20 5 820 18], ...
                'Text','Four-mode histogram & Reinhard normalization  |  Pre-flight inspector for H&E / IHC brightfield images', ...
                'FontSize',10,'FontColor',c.textDim);

            % ── Status bar ────────────────────────────────────────────
            app.StatusPanel = uipanel(app.UIFigure,'Position',[0 0 W 28], ...
                'BackgroundColor',[0.06 0.08 0.11],'BorderType','none');
            app.StatusLabel = uilabel(app.StatusPanel,'Position',[12 4 W-20 20], ...
                'Text','Ready','FontSize',10,'FontColor',c.textDim);

            % ── Left panel ────────────────────────────────────────────
            leftW = 408; panH = H-72-28;
            app.LeftPanel = uipanel(app.UIFigure,'Position',[0 28 leftW panH], ...
                'BackgroundColor',c.panel,'BorderType','none');

            topY = panH - 14;

            % Mode selector
            app.ModeLabel = uilabel(app.LeftPanel,'Position',[16 topY-2 300 16], ...
                'Text','NORMALISATION MODE','FontSize',9,'FontWeight','bold','FontColor',c.textDim);

            modeH = 126;
            app.ModeButtonGroup = uibuttongroup(app.LeftPanel, ...
                'Position',[16 topY-modeH-4 leftW-32 modeH], ...
                'BackgroundColor',[0.10 0.13 0.18],'BorderColor',[0.20 0.26 0.35], ...
                'SelectionChangedFcn',createCallbackFcn(app,@ModeButtonGroupSelectionChanged,true));

            mTxt = {'1 – Histogram matching  →  reference image', ...
                    '2 – Histogram matching  →  batch-average CDF', ...
                    '3 – Reinhard  →  reference image', ...
                    '4 – Reinhard  →  batch-average synthetic reference'};
            btns = cell(1,4);
            for k = 1:4
                btns{k} = uiradiobutton(app.ModeButtonGroup, ...
                    'Position',[10 modeH-k*28 leftW-52 22], ...
                    'Text',mTxt{k},'FontSize',10,'FontColor',c.text,'Value',(k==1));
            end
            app.Mode1Button=btns{1}; app.Mode2Button=btns{2};
            app.Mode3Button=btns{3}; app.Mode4Button=btns{4};

            % Mode description box
            dY = topY - modeH - 56;
            app.ModeDescPanel = uipanel(app.LeftPanel,'Position',[16 dY leftW-32 46], ...
                'BackgroundColor',[0.09 0.12 0.17],'BorderColor',[0.18 0.24 0.33]);
            app.ModeDescLabel = uilabel(app.ModeDescPanel,'Position',[8 2 leftW-50 40], ...
                'Text','','FontSize',9,'FontColor',c.textDim,'WordWrap','on');

            y = dY - 34;

            % Input folder
            app.InputLabel = uilabel(app.LeftPanel,'Position',[16 y 200 16], ...
                'Text','INPUT FOLDER','FontSize',9,'FontWeight','bold','FontColor',c.textDim);
            app.InputPathField = uieditfield(app.LeftPanel,'text','Position',[16 y-26 322 24], ...
                'BackgroundColor',[0.10 0.13 0.18],'FontColor',c.text,'FontSize',10);
            app.BrowseInputButton = uibutton(app.LeftPanel,'push','Position',[342 y-26 50 24], ...
                'Text','…','BackgroundColor',[0.18 0.22 0.30],'FontColor',c.text, ...
                'ButtonPushedFcn',createCallbackFcn(app,@BrowseInputButtonPushed,true));

            y = y - 52;

            % Reference image
            app.RefImageLabel = uilabel(app.LeftPanel,'Position',[16 y 340 16], ...
                'Text','REFERENCE IMAGE  (modes 1 & 3 only)', ...
                'FontSize',9,'FontWeight','bold','FontColor',c.textDim);
            app.RefImageField = uieditfield(app.LeftPanel,'text','Position',[16 y-26 322 24], ...
                'BackgroundColor',[0.10 0.13 0.18],'FontColor',c.text,'FontSize',10, ...
                'Placeholder','Select a reference image…');
            app.BrowseRefButton = uibutton(app.LeftPanel,'push','Position',[342 y-26 50 24], ...
                'Text','…','BackgroundColor',[0.18 0.22 0.30],'FontColor',c.text, ...
                'ButtonPushedFcn',createCallbackFcn(app,@BrowseRefButtonPushed,true));

            y = y - 52;

            % Output folder
            app.OutputLabel = uilabel(app.LeftPanel,'Position',[16 y 200 16], ...
                'Text','OUTPUT FOLDER','FontSize',9,'FontWeight','bold','FontColor',c.textDim);
            app.OutputPathField = uieditfield(app.LeftPanel,'text','Position',[16 y-26 322 24], ...
                'BackgroundColor',[0.10 0.13 0.18],'FontColor',c.text,'FontSize',10, ...
                'Placeholder','Select output folder…');
            app.BrowseOutputButton = uibutton(app.LeftPanel,'push','Position',[342 y-26 50 24], ...
                'Text','…','BackgroundColor',[0.18 0.22 0.30],'FontColor',c.text, ...
                'ButtonPushedFcn',createCallbackFcn(app,@BrowseOutputButtonPushed,true));

            y = y - 50;

            % Options
            app.OptionsLabel = uilabel(app.LeftPanel,'Position',[16 y 200 16], ...
                'Text','OUTPUT OPTIONS','FontSize',9,'FontWeight','bold','FontColor',c.textDim);
            y = y - 28;
            app.FormatDropDownLabel = uilabel(app.LeftPanel,'Position',[16 y 90 18], ...
                'Text','File format','FontSize',10,'FontColor',c.text);
            app.FormatDropDown = uidropdown(app.LeftPanel,'Items',{'tif','jpg','bmp'},'Value','tif', ...
                'Position',[110 y 80 22],'BackgroundColor',[0.10 0.13 0.18],'FontColor',c.text,'FontSize',10);
            y = y - 28;
            app.SaveLogCheckBox = uicheckbox(app.LeftPanel,'Position',[16 y 260 20], ...
                'Text','Save CSV normalization log','Value',true,'FontSize',10,'FontColor',c.text);
            y = y - 26;
            app.PreviewCheckBox = uicheckbox(app.LeftPanel,'Position',[16 y 200 20], ...
                'Text','Show live preview during run','Value',true,'FontSize',10,'FontColor',c.text);

            y = y - 38;

            % File list
            app.FileListLabel = uilabel(app.LeftPanel,'Position',[16 y 200 16], ...
                'Text','IMAGE QUEUE','FontSize',9,'FontWeight','bold','FontColor',c.textDim);
            app.LoadFilesButton = uibutton(app.LeftPanel,'push','Position',[224 y-1 80 20], ...
                'Text','Reload','FontSize',9,'BackgroundColor',[0.18 0.22 0.30],'FontColor',c.text, ...
                'ButtonPushedFcn',createCallbackFcn(app,@LoadFilesButtonPushed,true));
            app.ClearFilesButton = uibutton(app.LeftPanel,'push','Position',[308 y-1 60 20], ...
                'Text','Clear','FontSize',9,'BackgroundColor',[0.18 0.22 0.30],'FontColor',c.text, ...
                'ButtonPushedFcn',createCallbackFcn(app,@ClearFilesButtonPushed,true));

            listH = max(y - 136, 50);
            app.FileListBox = uilistbox(app.LeftPanel,'Position',[16 y-listH-22 leftW-32 listH], ...
                'BackgroundColor',[0.08 0.10 0.14],'FontColor',c.text,'FontSize',9, ...
                'ValueChangedFcn',createCallbackFcn(app,@FileListBoxValueChanged,true));
            app.FileCountLabel = uilabel(app.LeftPanel,'Position',[16 y-listH-44 300 18], ...
                'Text','0 images loaded','FontSize',9,'FontColor',c.textDim);

            % Progress label only
            app.ProgressLabel = uilabel(app.LeftPanel,'Position',[16 116 leftW-32 18], ...
                'Text','Idle','FontSize',9,'FontColor',c.textDim);

            % Buttons
            app.PreviewBatchButton = uibutton(app.LeftPanel,'push', ...
                'Position',[16 60 leftW-32 28], ...
                'Text','🔍  Preview All Methods Before Running', ...
                'FontSize',10,'FontWeight','bold', ...
                'BackgroundColor',[0.10 0.22 0.16],'FontColor',[0.28 0.92 0.58], ...
                'ButtonPushedFcn',createCallbackFcn(app,@PreviewBatchButtonPushed,true));
            app.RunButton = uibutton(app.LeftPanel,'push', ...
                'Position',[16 16 184 40],'Text','▶  Run Normalization', ...
                'FontSize',12,'FontWeight','bold','BackgroundColor',c.accent,'FontColor',[1 1 1], ...
                'ButtonPushedFcn',createCallbackFcn(app,@RunButtonPushed,true));
            app.CancelButton = uibutton(app.LeftPanel,'push', ...
                'Position',[208 16 184 40],'Text','✕  Cancel','FontSize',12, ...
                'BackgroundColor',c.danger,'FontColor',[1 1 1],'Enable','off', ...
                'ButtonPushedFcn',createCallbackFcn(app,@CancelButtonPushed,true));

            % ── Right panel – live run preview ─────────────────────────
            rX = leftW+2; rW = W-leftW-2;
            app.RightPanel = uipanel(app.UIFigure,'Position',[rX 28 rW panH], ...
                'BackgroundColor',c.bg,'BorderType','none');
            app.PreviewLabel = uilabel(app.RightPanel,'Position',[16 panH-24 300 18], ...
                'Text','LIVE PREVIEW','FontSize',9,'FontWeight','bold','FontColor',c.textDim);

            pH   = panH-44; imgH = round(pH*0.60); hiH = round(pH*0.30);
            imgW = round((rW-48)/2);
            app.AxesOriginal   = uiaxes(app.RightPanel,'Position',[16 hiH+32 imgW imgH],'Color',c.bg);
            app.AxesNormalized = uiaxes(app.RightPanel,'Position',[imgW+32 hiH+32 imgW imgH],'Color',c.bg);
            app.AxesHistOrig   = uiaxes(app.RightPanel,'Position',[16 16 imgW hiH],'Color',c.bg);
            app.AxesHistNorm   = uiaxes(app.RightPanel,'Position',[imgW+32 16 imgW hiH],'Color',c.bg);

            lp = {'FontSize',9,'FontColor',c.textDim,'BackgroundColor','none'};
            app.OriginalLabel   = uilabel(app.RightPanel,lp{:},'Position',[16 hiH+imgH+34 imgW 16],'Text','ORIGINAL');
            app.NormalizedLabel = uilabel(app.RightPanel,lp{:},'Position',[imgW+32 hiH+imgH+34 imgW 16],'Text','NORMALISED');
            app.HistOrigLabel   = uilabel(app.RightPanel,lp{:},'Position',[16 hiH+18 imgW 14],'Text','Histogram  (R · G · B)');
            app.HistNormLabel   = uilabel(app.RightPanel,lp{:},'Position',[imgW+32 hiH+18 imgW 14],'Text','Histogram  (R · G · B)');

            % ── Inspector panel (full overlay, hidden by default) ──────
            app.InspectorPanel = uipanel(app.UIFigure,'Position',[rX 28 rW panH], ...
                'BackgroundColor',c.bg,'BorderType','none','Visible','off');

            % Top bar
            topBarH = 30;
            topBarY = panH - topBarH - 4;

            app.InspTitleLabel = uilabel(app.InspectorPanel, ...
                'Position',[16 topBarY+6 400 22], ...
                'Text','PRE-FLIGHT INSPECTOR', ...
                'FontSize',12,'FontWeight','bold','FontColor',c.accentAlt,'BackgroundColor','none');

            app.InspImageLabel = uilabel(app.InspectorPanel, ...
                'Position',[220 topBarY+8 rW-420 18], ...
                'Text','–','FontSize',9,'FontColor',c.textDim,'BackgroundColor','none');

            app.InspCloseButton = uibutton(app.InspectorPanel,'push', ...
                'Position',[rW-110 topBarY+4 100 26],'Text','✕  Close', ...
                'FontSize',9,'BackgroundColor',[0.20 0.10 0.10],'FontColor',[1 0.55 0.55], ...
                'ButtonPushedFcn',createCallbackFcn(app,@InspCloseButtonPushed,true));

            % Nav bar
            navY = topBarY - 40;
            app.InspPrevButton = uibutton(app.InspectorPanel,'push', ...
                'Position',[16 navY 100 30],'Text','◀  Previous', ...
                'FontSize',10,'BackgroundColor',[0.18 0.22 0.30],'FontColor',c.text, ...
                'ButtonPushedFcn',createCallbackFcn(app,@InspPrevButtonPushed,true));
            app.InspNextButton = uibutton(app.InspectorPanel,'push', ...
                'Position',[122 navY 100 30],'Text','Next  ▶', ...
                'FontSize',10,'BackgroundColor',[0.18 0.22 0.30],'FontColor',c.text, ...
                'ButtonPushedFcn',createCallbackFcn(app,@InspNextButtonPushed,true));

            app.InspUseMethodDDLabel = uilabel(app.InspectorPanel, ...
                'Position',[240 navY+6 130 18],'Text','Select method:', ...
                'FontSize',10,'FontColor',c.text,'BackgroundColor','none');
            app.InspUseMethodDD = uidropdown(app.InspectorPanel, ...
                'Items',{'Mode 1 – Hist Match, Reference', ...
                         'Mode 2 – Hist Match, Batch Avg', ...
                         'Mode 3 – Reinhard, Reference', ...
                         'Mode 4 – Reinhard, Batch Avg'}, ...
                'Value','Mode 2 – Hist Match, Batch Avg', ...
                'Position',[372 navY 270 30], ...
                'BackgroundColor',[0.10 0.13 0.18],'FontColor',c.text,'FontSize',10);
            app.InspApplyButton = uibutton(app.InspectorPanel,'push', ...
                'Position',[650 navY 180 30],'Text','✔  Apply & Close', ...
                'FontSize',10,'FontWeight','bold', ...
                'BackgroundColor',[0.10 0.22 0.16],'FontColor',[0.28 0.92 0.58], ...
                'ButtonPushedFcn',createCallbackFcn(app,@InspApplyButtonPushed,true));

            app.InspStatusLabel = uilabel(app.InspectorPanel, ...
                'Position',[844 navY+6 rW-860 18],'Text','–', ...
                'FontSize',9,'FontColor',c.textDim,'BackgroundColor','none');

            % ── Image layout ───────────────────────────────────────────
            % Vertical space available below nav bar
            imgAreaY  = 16;
            imgAreaH  = navY - 24;
            lblH      = 18;
            gap       = 10;

            % Left column: original (narrow)
            origColW  = round(rW * 0.22);
            origAxH   = imgAreaH - lblH - 6;
            origAxY   = imgAreaY + lblH + 4;

            app.InspAxOrig = uiaxes(app.InspectorPanel, ...
                'Position',[16 origAxY origColW origAxH],'Color',c.bg);
            app.InspLblOrig = uilabel(app.InspectorPanel, ...
                'Position',[16 imgAreaY origColW lblH], ...
                'Text','ORIGINAL','HorizontalAlignment','center', ...
                'FontSize',9,'FontColor',c.textDim,'BackgroundColor','none');

            % Right area: 2×2 grid of normalised results
            gridX    = 16 + origColW + gap*2;
            gridW    = rW - gridX - 16;
            cellW    = round((gridW - gap) / 2);
            rowH     = round((imgAreaH - lblH*2 - gap*3) / 2);

            % Row positions (bottom row first since Y goes up)
            row1Y = imgAreaY + lblH + gap;            % bottom row axes Y
            row2Y = row1Y + rowH + lblH + gap;        % top row axes Y
            lbl1Y = imgAreaY;                         % bottom row label Y
            lbl2Y = row2Y - lblH - 2;                 % top row label Y

            col1X = gridX;
            col2X = gridX + cellW + gap;

            % M1: top-left  (Hist Match, Reference)
            app.InspAxM1 = uiaxes(app.InspectorPanel,'Position',[col1X row2Y cellW rowH],'Color',c.bg);
            app.InspLblM1 = uilabel(app.InspectorPanel,'Position',[col1X lbl2Y cellW lblH], ...
                'Text','MODE 1 – Hist Match, Reference','HorizontalAlignment','center', ...
                'FontSize',9,'FontColor',c.accent,'BackgroundColor','none');

            % M2: top-right  (Hist Match, Batch Avg)
            app.InspAxM2 = uiaxes(app.InspectorPanel,'Position',[col2X row2Y cellW rowH],'Color',c.bg);
            app.InspLblM2 = uilabel(app.InspectorPanel,'Position',[col2X lbl2Y cellW lblH], ...
                'Text','MODE 2 – Hist Match, Batch Avg','HorizontalAlignment','center', ...
                'FontSize',9,'FontColor',c.accent,'BackgroundColor','none');

            % M3: bottom-left  (Reinhard, Reference)
            app.InspAxM3 = uiaxes(app.InspectorPanel,'Position',[col1X row1Y cellW rowH],'Color',c.bg);
            app.InspLblM3 = uilabel(app.InspectorPanel,'Position',[col1X lbl1Y cellW lblH], ...
                'Text','MODE 3 – Reinhard, Reference','HorizontalAlignment','center', ...
                'FontSize',9,'FontColor',c.accentAlt,'BackgroundColor','none');

            % M4: bottom-right  (Reinhard, Batch Avg)
            app.InspAxM4 = uiaxes(app.InspectorPanel,'Position',[col2X row1Y cellW rowH],'Color',c.bg);
            app.InspLblM4 = uilabel(app.InspectorPanel,'Position',[col2X lbl1Y cellW lblH], ...
                'Text','MODE 4 – Reinhard, Batch Avg','HorizontalAlignment','center', ...
                'FontSize',9,'FontColor',c.accentAlt,'BackgroundColor','none');

            % Style all inspector axes
            for iax = {app.InspAxOrig,app.InspAxM1,app.InspAxM2,app.InspAxM3,app.InspAxM4}
                iax{1}.XColor=c.textDim; iax{1}.YColor=c.textDim;
                iax{1}.Title.Color=c.textDim; iax{1}.Title.FontSize=8;
                iax{1}.XTick=[]; iax{1}.YTick=[];
                axis(iax{1},'image');
            end

            app.UIFigure.Visible = 'on';
        end

    end % createComponents

    % =====================================================================
    %  CREATION & DELETION
    % =====================================================================
    methods (Access = public)

        function app = Chameleon
            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @startupFcn);
            if nargout == 0, clear app; end
        end

        function delete(app)
            delete(app.UIFigure);
        end

    end

end % classdef


% =========================================================================
%  STANDALONE UTILITY FUNCTIONS
% =========================================================================

function img = ensureUint8RGB(img)
    if size(img,3)==1,       img = repmat(img,[1 1 3]); end
    if size(img,3)==4,       img = img(:,:,1:3);        end
    if isa(img,'uint16'),    img = uint8(double(img)/65535*255);
    elseif isfloat(img),     img = uint8(img*255);
    elseif ~isa(img,'uint8'),img = im2uint8(img);
    end
end

function cdf = computeCDF(img)
    cdf = zeros(256,3);
    for ch = 1:3, cdf(:,ch) = computeCDFChannel(img(:,:,ch)); end
end

function cdf = computeCDFChannel(ch)
    h = imhist(ch,256); cdf = cumsum(h)/sum(h);
end

function out = histogramMatch(src, srcCDF, tgtCDF)
    lut = zeros(1,256,'uint8'); j = 1;
    for i = 1:256
        while j < 256 && tgtCDF(j) < srcCDF(i), j = j+1; end
        lut(i) = j-1;
    end
    out = lut(double(src)+1);
end

function stats = computeReinhardStats(img)
    lab        = rgb2lab(img);
    stats.mu   = squeeze(mean(lab,[1 2]))';
    stats.sigma= squeeze(std(reshape(lab,[],3)))';
end

function [imgNorm, srcStats] = reinhardNormalize(img, tgtStats)
    lab      = rgb2lab(img);
    srcStats = computeReinhardStats(img);
    labOut   = lab;
    for ch = 1:3
        if srcStats.sigma(ch) > 1e-6
            labOut(:,:,ch) = (lab(:,:,ch) - srcStats.mu(ch)) ...
                             / srcStats.sigma(ch) * tgtStats.sigma(ch) ...
                             + tgtStats.mu(ch);
        end
    end
    labOut(:,:,1) = max(0,   min(100,  labOut(:,:,1)));
    labOut(:,:,2) = max(-128, min(127, labOut(:,:,2)));
    labOut(:,:,3) = max(-128, min(127, labOut(:,:,3)));
    imgNorm = im2uint8(lab2rgb(labOut));
end

function styleInspAxes(ax, titleStr, col)
    ax.Title.String   = titleStr;
    ax.Title.Color    = col;
    ax.Title.FontSize = 9;
    ax.XTick = []; ax.YTick = [];
    axis(ax,'image');
end

function noRefMsg(ax, titleStr, c)
    cla(ax);
    text(ax, 0.5, 0.5, {'No reference image set', '(browse to enable)'}, ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Color',c.textDim,'FontSize',9,'Units','normalized');
    ax.XTick=[]; ax.YTick=[];
    ax.Title.String = titleStr;
    ax.Title.Color  = c.textDim;
end

function plotRGBHist(ax, img, colors)
    cla(ax); hold(ax,'on');
    cls = {'r','g','b'};
    for ch = 1:3
        h = imhist(img(:,:,ch),64); h = h/(max(h)+eps);
        plot(ax,h,cls{ch},'LineWidth',1.2);
    end
    hold(ax,'off');
end

function styleHistAxes(ax, titleStr, colors)
    ax.Color=colors.bg; ax.XColor=colors.textDim; ax.YColor=colors.textDim;
    ax.Title.String=titleStr; ax.Title.Color=colors.textDim;
    ax.Title.FontSize=8; ax.XLim=[0 64]; ax.YLim=[0 1];
    ax.Box='off'; ax.FontSize=7;
end

function wd = wassersteinDist(a,b)
    e=linspace(0,1,257);
    ha=histcounts(a,e,'Normalization','pdf')*(1/256);
    hb=histcounts(b,e,'Normalization','pdf')*(1/256);
    wd=sum(abs(cumsum(ha)-cumsum(hb)))/256;
end

function saveImage(img, path, fmt, quality)
    switch fmt
        case 'jpg', imwrite(img,path,'jpeg','Quality',quality);
        case 'tif', imwrite(img,path,'tiff','Compression','lzw','WriteMode','overwrite');
        case 'bmp', imwrite(img,path,'bmp');
        otherwise,  imwrite(img,path);
    end
end

function writeCSVLog(outDir, logData, header, modeName)
    ts  = datestr(now,'yyyymmdd_HHMMSS'); %#ok<DATST>
    pth = fullfile(outDir, sprintf('normlog_%s_%s.csv', modeName, ts));
    try
        fid = fopen(pth,'w');
        fprintf(fid,'# Chameleon | Mode: %s | %s\n',modeName,datestr(now)); %#ok<DATST>
        fprintf(fid,'%s,',header{1:end-1}); fprintf(fid,'%s\n',header{end});
        for r = 1:size(logData,1)
            row = logData(r,:);
            for k = 1:numel(row)-1
                if isnumeric(row{k}), fprintf(fid,'%.5f,',row{k});
                else,                 fprintf(fid,'%s,',   row{k}); end
            end
            if isnumeric(row{end}), fprintf(fid,'%.5f\n',row{end});
            else,                   fprintf(fid,'%s\n',   row{end}); end
        end
        fclose(fid);
    catch ME
        warning('BatchNorm:logError','Log write failed: %s',ME.message);
    end
end

function name = getFileName(fp)
    [~,n,e] = fileparts(fp); name = [n e];
end
