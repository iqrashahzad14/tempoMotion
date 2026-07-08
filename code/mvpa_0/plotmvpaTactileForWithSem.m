clear

%% Load time axis
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/preprocess/sub-001/sub-001_preprocessed.mat')
time = data_clean.time{1};

%% Load decoding results
base = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_tactileFor';

nSub = 6;

for s = 1:nSub

    fname = fullfile(base, ...
        sprintf('sub%03d', s), ...
        'binarydecoding_svm_touch_decoding', ...
        'iter20_pt3', ...
        'acc_libsvm_touch_decoding.mat');

    tmp = load(fname);

    if s == 1
        acc = zeros([size(tmp.acc_comp_iter), nSub]);
        decode_name = tmp.decode_name;
    end

    acc(:,:,:,s) = tmp.acc_comp_iter;

end

% acc size = decoding condition x time x iteration x subject

%% Plot mean accuracy with SEM across subjects
figure;

for dc = 1:3

    subplot(3,1,dc)
    hold on

    % Average iterations within each subject
    % subj_data size = time x subject
    subj_data = squeeze(mean(acc(dc,:,:,:), 3));

    % Mean across subjects
    y = mean(subj_data, 2);

    % SEM across subjects
    sem = std(subj_data, 0, 2) ./ sqrt(size(subj_data, 2));

    % Shaded SEM area
    fill([time fliplr(time)], ...
         [(y - sem)' fliplr((y + sem)')], ...
         [0.8 0.8 0.8], ...
         'EdgeColor', 'none', ...
         'FaceAlpha', 0.5);

    % Mean line
    plot(time, y, 'k', 'LineWidth', 2);

    % Reference lines
    yline(0.5, 'k--');
    xline(0, 'k-');

    ylim([0.3 0.7]);

    xlabel('Time (s)');
    ylabel('Accuracy');
    title(decode_name{dc}, 'Interpreter', 'none');

    box off
    hold off

end