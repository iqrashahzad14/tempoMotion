%% 
%To find out what the trigger codes are in your BDF file, you can use the following code snippet

Copyevent = ft_read_event(filename);

% select only the trigger codes, not the battery and CMS status
sel = find(strcmp({event.type}, 'STATUS'));
event = event(sel);

plot([event.sample], [event.value], '.')
To find out what the trigger codes are in your BDF file, you can use the following code snippet

Copyevent = ft_read_event(filename);

% select only the trigger codes, not the battery and CMS status
sel = find(strcmp({event.type}, 'STATUS'));
event = event(sel);

plot([event.sample], [event.value], '.')
