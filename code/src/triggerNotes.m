%% Trigger notes
% # Trigger map:
% # 4 unique triggers for each visual direction
% # 4 unique triggers for each tactile direction in tac_up
% # 4 unique triggers for each tactile direction in tac_down
% # plus target marker and response marker in each block type
% TRIG = {
%     "visual": {
%         "left": 11,
%         "right": 12,
%         "up": 13,
%         "down": 14,
%         "target": 15,
%         "resp": 16,
%     },
%     "tac_up": {
%         "wrist_to_finger": 21,
%         "finger_to_wrist": 22,
%         "pinky_to_thumb": 23,
%         "thumb_to_pinky": 24,
%         "target": 25,
%         "resp": 26,
%     },
%     "tac_down": {
%         "wrist_to_finger": 31,
%         "finger_to_wrist": 32,
%         "pinky_to_thumb": 33,
%         "thumb_to_pinky": 34,
%         "target": 35,
%         "resp": 36,
%     },
% }

%%
% BioSemi-style status values with an offset. Your real trigger code is:
% trigger = event.value - 65280;
% 65291 -> 11 visual left
% 65292 -> 12 visual right
% 65293 -> 13 visual up
% 65294 -> 14 visual down
% 65295 -> 15 visual target
% 65296 -> 16 visual resp

% 65301 -> 21 tac_up wrist_to_finger
% 65302 -> 22 tac_up finger_to_wrist
% 65303 -> 23 tac_up pinky_to_thumb
% 65304 -> 24 tac_up thumb_to_pinky
% 65305 -> 25 tac_up target
% 65306 -> 26 tac_up resp

% 65311 -> 31 tac_down wrist_to_finger
% 65312 -> 32 tac_down finger_to_wrist
% 65313 -> 33 tac_down pinky_to_thumb
% 65314 -> 34 tac_down thumb_to_pinky
% 65315 -> 35 tac_down target
% 65316 -> 36 resp