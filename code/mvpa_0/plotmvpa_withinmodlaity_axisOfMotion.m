clear

%% Load time axis
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/preprocess/sub-001/sub-001_preprocessed.mat')
time = data_clean.time{1};

%% Axis of motion within modality
base = '/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_axisOfmotion';

nSub = 6;

for s = 1:nSub

    fname = fullfile(base, ...
        sprintf('sub%03d', s), ...
        'binarydecoding_svm_grouped', ...
        'iter20_pt3', ...
        'acc_libsvm_grouped.mat');

    tmp = load(fname);

    if s == 1
        acc = zeros([size(tmp.acc_comp_iter), nSub]);
    end

    acc(:,:,:,:,s) = tmp.acc_comp_iter;

end

% acc dimensions:
% comparison x time x iteration x modality x subject

%% Plot
modality_label = {'visual', 'tactiledown', 'tactileup'};

figure;

for m = 1:3

    subplot(3,1,m)

    % average over comparisons, iterations, and subjects
    y = squeeze(mean(mean(mean(acc(:,:,:,m,:), 3), 1), 5));

    plot(time, y, 'LineWidth', 1.5)
    hold on

    yline(0.5, 'k--')   % chance
    xline(0, 'k-')

    ylim([0.3 0.7])
    xlabel('Time (s)')
    ylabel('Accuracy')
    title(modality_label{m})

    hold off

end