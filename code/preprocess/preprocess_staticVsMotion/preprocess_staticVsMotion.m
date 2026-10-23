%% Preprocessing: static-vs-motion supplementary session (3 subjects)
%
% Same pipeline as code/preprocess/preprocess_bandstop45.m (high-pass 0.5
% Hz + band-stop 49-52 Hz -> epoch/run splitting -> resample to 256 Hz ->
% ICA -> component rejection -> low-pass 45 Hz -> average reference ->
% re-epoch -> baseline correction -> threshold artifact rejection),
% adapted for the supplementary "static vs motion" recording
% (<sub>_static.bdf): only 3 subjects completed this session (sub-001,
% sub-004, sub-006), and each has just ONE visual block + ONE tactile
% block (no tactile-up/tactile-down hand-posture split), each block
% containing the 4 motion directions PLUS a static condition:
%   visual:  11-14 (motion directions), 17 (static), 15 (target), 16 (resp)
%   tactile: 21-24 (motion directions), 27 (static), 25 (target), 26 (resp)
% (confirmed directly from the raw event channel, matches
% inputs/references/tempoMotion_studyDesign.docx section 1.3,
% "Experiment 1 (Static vs. Motion)").
%
% Workflow for the ICA component rejection step (same 2-stage process as
% preprocess_bandstop45.m):
% 1) Run this script with rejectComponents left empty ([]) for every
%    subject. For each subject it computes ICA, saves a topography figure
%    to outputs/derivatives/preprocess/preprocess_staticVsMotion/<sub>/<sub>_ica_components.png,
%    caches the ICA result, then skips the rest of the pipeline for that
%    subject.
% 2) Inspect each *_ica_components.png, decide which component(s) is the
%    eye-blink/artifact component, and fill it into rejectComponents
%    below.
% 3) Rerun this script. Subjects with a component number set now load the
%    cached ICA and run the remaining steps through to the final save.

clear;

%% Add FieldTrip
addpath('/Users/iqrashahzad/Documents/MATLAB/fieldtrip');
ft_defaults;
[~, ftpath] = ft_version;

%% Define dataset and paths
projectDir = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2';
rawDir     = fullfile(projectDir, 'inputs', 'raw');
outDir     = fullfile(projectDir, 'outputs', 'derivatives', 'preprocess', 'preprocess_staticVsMotion');

%% Subjects to process
% 3 subjects completed the static-vs-motion session (sub-001, sub-004,
% sub-006), but sub-004's static.bdf recording contains no usable
% stimulus triggers (event/status channel has only 3 non-stimulus
% entries, and the recording is ~5 min shorter than the other two) --
% the trigger/status channel was evidently not active during that
% session. Confirmed no alternate/backup file exists. Proceeding with
% N=2 (sub-001, sub-006) per explicit user decision.
subjects = {'sub-001', 'sub-006'};

%% ICA component(s) to reject per subject
% Fill in after inspecting *_ica_components.png (frontal-polar,
% bilaterally symmetric topography = eye-blink component).
rejectComponents = containers.Map(subjects, {[1 5 7], [3]});

%% Loop over subjects
for s = 1:numel(subjects)

    subDir = subjects{s};
    fprintf('\n=== %s (static vs motion) ===\n', subDir);

    subOutDir = fullfile(outDir, subDir);
    if ~exist(subOutDir, 'dir')
        mkdir(subOutDir);
    end

    icaCacheFile = fullfile(subOutDir, [subDir '_ica_intermediate.mat']);
    compFigFile  = fullfile(subOutDir, [subDir '_ica_components.png']);

    if ~exist(icaCacheFile, 'file')

        %% ---- Stage 1: import through ICA ----
        rawfile = fullfile(rawDir, subDir, [erase(subDir,'-') '_static.bdf']);

        cfg             = [];
        cfg.datafile    = rawfile;
        cfg.headerfile  = rawfile;
        cfg.channel     = 1:132;
        data            = ft_preprocessing(cfg);

        % High pass + band-stop (line noise) filtering
        cfg = [];
        cfg.hpfilter            = 'yes';
        cfg.hpfreq               = 0.5;
        cfg.hpfilttype           = 'but';
        cfg.hpfiltord            = 4;
        cfg.bsfilter             = 'yes';
        cfg.bsfreq               = [49 52];
        cfg.bsfilttype           = 'but';
        cfg.bsfiltord            = 4;

        data_filt = ft_preprocessing(cfg, data);

        %% Epoching and concatenate runs
        event = ft_read_event(rawfile);

        event_values = ({event.value});
        event_sample = ({event.sample});

        % Stimulus-locked epochs only
        visual_trigs = [65291 65292 65293 65294 65297];   % 11 12 13 14 (motion) + 17 (static)
        tac_trigs    = [65301 65302 65303 65304 65307];   % 21 22 23 24 (motion) + 27 (static)
        target_trig  = [65295 65305];                     % 15 25
        stim_trigs = [visual_trigs tac_trigs target_trig];

        ind = find(cellfun(@(c) any(ismember(c, stim_trigs)), event_values));
        event_samplemat = cell2mat(event_sample(ind));
        event_valuesmat = cell2mat(event_values(ind));

        diffSamp = event_samplemat(2:end) - event_samplemat(1:end-1);

        gaplength = data_filt.fsample*5;
        prestim  = 0.25;
        poststim = 1.5;

        run_end   = [event_samplemat(find(diffSamp > gaplength))  event_samplemat(end)] + (data_filt.fsample*poststim);
        run_start = [event_samplemat(1) event_samplemat(find(diffSamp > gaplength)+1)]  - (data_filt.fsample*prestim);

        cfg = [];
        cfg.trl = [run_start; run_end; ones(1,length(run_start)).* -(data_filt.fsample*prestim)]';
        data_runs = ft_redefinetrial(cfg, data_filt);

        %% adjust trigger information
        epoch_info = [];
        for run = 1:numel(run_start)
            ind = find(event_samplemat >= run_start(run) & event_samplemat <= run_end(run));
            epoch_info{run}(:,1) = event_samplemat(ind) - (data_filt.fsample*prestim)-1; %onset
            epoch_info{run}(:,2) = event_samplemat(ind) + (data_filt.fsample*poststim); %offset
            epoch_info{run}(:,3) = ones(1,numel(event_valuesmat(ind))).* - (data_filt.fsample*prestim);
            epoch_info{run}(:,4) = event_valuesmat(ind) - 65280;

            % delete the extra trigger during targets
            ind = find(ismember(epoch_info{run}(:,4),[15 25]));
            epoch_info{run}([ind-1;ind],:) = [];
        end

        %% resampling
        cfg = [];
        cfg.resamplefs = 256;
        cfg.detrend    = 'no';
        cfg.keepsampleinfo = 'yes';
        data_resamp = ft_resampledata(cfg, data_runs);

        epoch_info_resamp = epoch_info;
        for run = 1:numel(epoch_info)
            for col = 1:3
                epoch_info_resamp{run}(:,col) = floor(epoch_info{run}(:,col) * cfg.resamplefs / data_runs.fsample);
            end
            % make sure all trials are same length
            mn = min(epoch_info_resamp{run}(:,2) - epoch_info_resamp{run}(:,1));
            ind = find(epoch_info_resamp{run}(:,2) - epoch_info_resamp{run}(:,1)>mn);
            epoch_info_resamp{run}(ind,2) = epoch_info_resamp{run}(ind,2)-1;
        end

        %% ica
        cfg = [];
        cfg.channel = {'A*','B*','C*','D*'};   % BioSemi 128 scalp channels
        data_ica_in = ft_selectdata(cfg, data_resamp);

        cfg = [];
        cfg.method  = 'runica';
        cfg.channel = 'all';
        comp = ft_componentanalysis(cfg, data_ica_in);

        %% save component topographies for offline inspection
        f = figure('Visible', 'off');
        cfg = [];
        cfg.component = 1:length(comp.label);
        cfg.layout    = fullfile(ftpath, 'template', 'layout', 'biosemi128.lay');
        cfg.comment   = 'no';
        ft_topoplotIC(cfg, comp);
        set(f, 'Position', [0 0 1600 1200]);
        saveas(f, compFigFile);
        close(f);
        fprintf('Saved ICA component topographies to %s\n', compFigFile);

        %% cache ICA result so stage 2 does not need to recompute it
        save(icaCacheFile, 'comp', 'data_ica_in', 'epoch_info_resamp', '-v7.3');

        fprintf('Inspect %s, decide which component(s) to remove for %s,\n', compFigFile, subDir);
        fprintf('set it in rejectComponents in this script, then rerun.\n');
        continue

    end

    %% ---- Stage 2: component rejection through to final save ----
    comps = rejectComponents(subDir);
    if isempty(comps)
        fprintf('ICA already computed for %s (see %s) but no component number set yet - skipping.\n', subDir, compFigFile);
        continue
    end

    loaded = load(icaCacheFile, 'comp', 'data_ica_in', 'epoch_info_resamp');
    comp = loaded.comp;
    data_ica_in = loaded.data_ica_in;
    epoch_info_resamp = loaded.epoch_info_resamp;

    cfg = [];
    cfg.component = comps;
    data_clean_ica = ft_rejectcomponent(cfg, comp, data_ica_in);

    %% lpf
    cfg            = [];
    cfg.lpfilter   = 'yes';
    cfg.lpfreq     = 45;
    cfg.lpfilttype = 'but';
    cfg.lpfiltord  = 4;

    data_filt_lpf = ft_preprocessing(cfg, data_clean_ica);

    %% Re-reference to average of all EEG channels
    cfg = [];
    cfg.reref      = 'yes';
    cfg.refchannel = 'all';   % average reference
    cfg.channel    = 'EEG';

    data_ref = ft_preprocessing(cfg, data_filt_lpf);

    %% epoch trials
    data_ref = rmfield(data_ref, 'sampleinfo');
    epoch_info_resamp2 = epoch_info_resamp;
    data_tmp = cell(1, numel(data_ref.trial));
    for run = 1:numel(data_ref.trial)

        epoch_info_resamp2{run}(:,1) = epoch_info_resamp{run}(:,1) - (epoch_info_resamp{run}(1,1)-1);
        epoch_info_resamp2{run}(:,2) = epoch_info_resamp{run}(:,2) - (epoch_info_resamp{run}(1,1));

        cfg = [];
        cfg.trl = epoch_info_resamp2{run};
        cfg.trials = run;
        data_tmp{run} = ft_redefinetrial(cfg, data_ref);

    end

    cfg = [];
    cfg.keepsampleinfo = 'no';
    data_epoch = ft_appenddata(cfg, data_tmp{:});

    %% Baseline correction
    % Baseline: 250 ms before stimulus onset
    cfg = [];
    cfg.demean = 'yes';
    cfg.baselinewindow = [-inf 0];

    data_base = ft_preprocessing(cfg, data_epoch);

    %% artifact rejection
    cfg = [];
    cfg.artfctdef.threshold.channel = 'EEG';
    cfg.artfctdef.threshold.min     = -100;   % lower limit, uV
    cfg.artfctdef.threshold.max     = 100;    % upper limit, uV

    [cfg, artifact_threshold] = ft_artifact_threshold(cfg, data_base);

    cfg.artfctdef.reject = 'complete';  % removes whole trials
    data_clean = ft_rejectartifact(cfg, data_base);

    %% Save final preprocessed EEG data
    save(fullfile(subOutDir, [subDir '_preprocessed.mat']), 'data_clean', '-v7.3');
    fprintf('Saved final preprocessed data for %s\n', subDir);

end
