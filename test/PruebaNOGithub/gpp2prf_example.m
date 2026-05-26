%% ejemplo gpp to pref dir. 


% 2 objectives, 2 ranges
pref   = [0 .3 3;    
          0 5 9];   
bounds = [10 10;    % max
          0  0];    % min

[M,Md]=plotPreferenceDirections2D(pref, bounds)


% 2 objectives, 2 ranges
pref   = [0 .3 3 5;   
          0 5 9  10];   
bounds = [20 20;    
          0  0];   

[M,Md]=plotPreferenceDirections2D(pref, bounds)

