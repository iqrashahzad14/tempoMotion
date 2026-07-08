clear
%%
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/preprocess/sub-001/sub-001_preprocessed.mat')
%%  4 directions within modality  
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_1/sub001/binarydecoding_svm/iter20_pt3/acc_libsvm.mat')
acc_comp_iter1 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_1/sub002/binarydecoding_svm/iter20_pt3/acc_libsvm.mat')
acc_comp_iter2 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_1/sub003/binarydecoding_svm/iter20_pt3/acc_libsvm.mat')
acc_comp_iter3 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_1/sub004/binarydecoding_svm/iter20_pt3/acc_libsvm.mat')
acc_comp_iter4 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_1/sub005/binarydecoding_svm/iter20_pt3/acc_libsvm.mat')
acc_comp_iter5 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_1/sub006/binarydecoding_svm/iter20_pt3/acc_libsvm.mat')
acc_comp_iter6 = acc_comp_iter;

%% axis of motion within modality 
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_axisOfmotion/sub001/binarydecoding_svm_grouped/iter20_pt3/acc_libsvm_grouped.mat')
acc_comp_iter1 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_axisOfmotion/sub002/binarydecoding_svm_grouped/iter20_pt3/acc_libsvm_grouped.mat')
acc_comp_iter2 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_axisOfmotion/sub003/binarydecoding_svm_grouped/iter20_pt3/acc_libsvm_grouped.mat')
acc_comp_iter3 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_axisOfmotion/sub004/binarydecoding_svm_grouped/iter20_pt3/acc_libsvm_grouped.mat')
acc_comp_iter4 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_axisOfmotion/sub005/binarydecoding_svm_grouped/iter20_pt3/acc_libsvm_grouped.mat')
acc_comp_iter5 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_axisOfmotion/sub006/binarydecoding_svm_grouped/iter20_pt3/acc_libsvm_grouped.mat')
acc_comp_iter6 = acc_comp_iter;

%% tactile FoR
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_tactileFor/sub001/binarydecoding_svm_touch_decoding/iter20_pt3/acc_libsvm_touch_decoding.mat')
acc_comp_iter1 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_tactileFor/sub002/binarydecoding_svm_touch_decoding/iter20_pt3/acc_libsvm_touch_decoding.mat')
acc_comp_iter2 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_tactileFor/sub003/binarydecoding_svm_touch_decoding/iter20_pt3/acc_libsvm_touch_decoding.mat')
acc_comp_iter3 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_tactileFor/sub004/binarydecoding_svm_touch_decoding/iter20_pt3/acc_libsvm_touch_decoding.mat')
acc_comp_iter4 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_tactileFor/sub005/binarydecoding_svm_touch_decoding/iter20_pt3/acc_libsvm_touch_decoding.mat')
acc_comp_iter5 = acc_comp_iter;
load('/Users/iqrashahzad/Files/eeg/tempoMotion_ai2/outputs/derivatives/mvpa_tactileFor/sub006/binarydecoding_svm_touch_decoding/iter20_pt3/acc_libsvm_touch_decoding.mat')
acc_comp_iter6 = acc_comp_iter;


%%
acc = cat(5,acc_comp_iter1,acc_comp_iter2,acc_comp_iter3,acc_comp_iter4,acc_comp_iter5,acc_comp_iter6);
% acc = auc_comp_iter;
%%
figure;
subplot(3,1,1);
plot(data_clean.time{1},mean(mean(mean(acc(:,:,:,1,:),3),1),5));
hold on;
plot(data_clean.time{1},zeros(1,size(data_clean.time{1},2))+0.5,'k--');
yline(0); xline(0);
hold off;
subtitle('visual');

subplot(3,1,2);
plot(data_clean.time{1},mean(mean(mean(acc(:,:,:,2,:),3),1),5));
hold on;
plot(data_clean.time{1},zeros(1,size(data_clean.time{1},2))+0.5,'k--');
yline(0); xline(0);
hold off;
subtitle('tactiledown');

subplot(3,1,3);
plot(data_clean.time{1},mean(mean(mean(acc(:,:,:,3,:),3),1),5));
hold on;
plot(data_clean.time{1},zeros(1,size(data_clean.time{1},2))+0.5,'k--');
yline(0); xline(0);
hold off;
subtitle('tactileup');

%%

% figure;plot(data_ref.time{1},mean(mean(mean(auc_comp_iter1(:,:,:,1,:),3),1),5))
% figure;plot(data_ref.time{1},mean(mean(mean(auc_comp_iter1(:,:,:,2,:),3),1),5))
% figure;plot(data_ref.time{1},mean(mean(mean(auc_comp_iter1(:,:,:,3,:),3),1),5))