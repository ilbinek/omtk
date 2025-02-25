["score_boards start", "DEBUG", false] call omtk_log;

call omtk_rollback_to_start_time;

if (isServer) then {
	_endHour = 0;
	_endMinute = 0;
	_endSecond = 0;
	_omtk_mission_duration = 0;

	_mission_duration_override = missionNamespace getVariable ["OMTK_SB_MISSION_DURATION_OVERRIDE", nil];
	if (!isNil "_mission_duration_override") then {
		_endHour   = OMTK_SB_MISSION_DURATION_OVERRIDE select 0;
		_endMinute = OMTK_SB_MISSION_DURATION_OVERRIDE select 1;
		_endSecond = OMTK_SB_MISSION_DURATION_OVERRIDE select 2;
		_omtk_mission_duration = 3600*_endHour + 60*_endMinute + _endSecond - 1;
	} else {
		_mission_duration = ("OMTK_MODULE_SCORE_BOARD" call BIS_fnc_getParamValue);
		_omtk_mission_duration = _mission_duration - 1;
		_endHour   = floor (_mission_duration/3600);
		_endMinute = floor ((_mission_duration - (3600*_endHour)) / 60);
		_endSecond = _mission_duration - (3600*_endHour) - (60*_endMinute);
	};

	_initHour = floor daytime;
	_initMinute = floor ((daytime - _initHour) * 60);
	_initSecond = floor (((((daytime) - (_initHour))*60) - _initMinute)*60);

	_omtk_mission_endTime = (_initHour + _endHour)*3600 + (_initMinute + _endMinute)*60 + _initSecond + _endSecond;
	missionNamespace setVariable ["omtk_mission_endTime", _omtk_mission_endTime];

	_omtk_mission_endTime_hour = floor (_omtk_mission_endTime/3600);
	_omtk_mission_endTime_minute = floor ((_omtk_mission_endTime - (3600*_omtk_mission_endTime_hour)) / 60);
	_omtk_mission_endTime_second = _omtk_mission_endTime - (3600*_omtk_mission_endTime_hour) - (60*_omtk_mission_endTime_minute);

	_txtFormat = "%1h%2m";
	if (_omtk_mission_endTime_minute < 10) then {_txtFormat = "%1h0%2m"; };
	_end_time_txt = format [_txtFormat,_omtk_mission_endTime_hour,_omtk_mission_endTime_minute];
	_end_time_txt = format ["<t shadow='1' shadowColor='#CC0000'>End of mission : %1</t>", _end_time_txt];
	_end_time_txt = parseText _end_time_txt;
	
	_omtk_mission_end_time_txt = composeText [_end_time_txt];
	missionNamespace setVariable ["omtk_mission_end_time_txt",_omtk_mission_end_time_txt];
	publicVariable "omtk_mission_end_time_txt";
	
	// SCHEDULE EVENTS
	[{
		//("[OMTK] 20 Minutes Left") remoteExecCall ["systemChat"];
		("20 Minutes Left") remoteExecCall ["hint"];
	}, [], _omtk_mission_duration - 1200] call KK_fnc_setTimeout;		// 20 minutes warning (1200 secs = 2 mins)
	[omtk_sb_compute_scoreboard, [], _omtk_mission_duration] call KK_fnc_setTimeout;
	[omtk_sb_start_mission_end, [], _omtk_mission_duration+2] call KK_fnc_setTimeout;
	if (isClass(configFile >> "CfgPatches" >> "ocap")) then {[ocap_fnc_exportData, [], _omtk_mission_duration+10] call KK_fnc_setTimeout;};
	
	_unlock_heli_var = missionNamespace getVariable ["OMTK_SB_UNLOCK_HELI_VARS", nil];
	_unlock_heli_time = missionNamespace getVariable ["OMTK_SB_UNLOCK_HELI_TIME", nil];
	if (!isNil "_unlock_heli_var" && !isNil "_unlock_heli_time") then {
		omtk_unlock_helis = {
			("Locked Vehicles have been Unlocked (if any)") remoteExecCall ["systemChat"];
			{
				_heli = missionNamespace getVariable [_x, objNull];
				if (!isnil("_heli")) then { _heli lock 0; };
			} forEach OMTK_SB_UNLOCK_HELI_VARS;
		};
		[omtk_unlock_helis, [], _unlock_heli_time] call KK_fnc_setTimeout; // unlock helis later as defined in init variable
	};
	// OBJ
	_omtk_sb_objectives = [];
	_omtk_sb_scores = [0,0,0];
	_omtk_sb_flags = [];

	{
		_side = _x select 1;
		_type = _x select 2;
		_values = _x select 4;
		_newFlag = 0;
		
		switch(_side) do {
			case "BLUEFOR":	{
				_x set [1, West];
				[_omtk_sb_objectives, _x] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
			};
			case "REDFOR":	{
				_x set [1, East];
				[_omtk_sb_objectives, _x] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
			};
			case "GREENFOR":	{
				_x set [1, Resistance];
				[_omtk_sb_objectives, _x] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
			};
			// Duplicates the objective for both factions
			case "BLUEFOR+REDFOR":	{
				_x set [1, West];
				[_omtk_sb_objectives, _x] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
				_x2 = + _x;
				_x2 set [1, East];
				// To accomodate timed capzones, the flag used by the duplicated objective is the original + 10
				if (_type == "T_INSIDE") then {
					_newFlag = (_values select 0) + 10;
					_x2 set [4, [_newFlag,0]];
				};
				[_omtk_sb_objectives, _x2] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
			};
			case "BLUEFOR+GREENFOR":	{
				_x set [1, West];
				[_omtk_sb_objectives, _x] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
				_x2 = + _x;
				_x2 set [1, Resistance];
				[_omtk_sb_objectives, _x2] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
			};
			case "REDFOR+GREENFOR":	{
				_x set [1, East];
				[_omtk_sb_objectives, _x] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
				_x2 = + _x;
				_x2 set [1, Resistance];
				[_omtk_sb_objectives, _x2] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
			};
			case "BLUEFOR+REDFOR+GREENFOR":	{
				_x set [1, West];
				[_omtk_sb_objectives, _x] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
				_x2 = + _x;
				_x2 set [1, East];
				[_omtk_sb_objectives, _x2] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
				_x3 = + _x;
				_x3 set [1, Resistance];
				[_omtk_sb_objectives, _x3] call BIS_fnc_arrayPush;
				[_omtk_sb_scores, false]  call BIS_fnc_arrayPush;
			};
			default	{
				["unknown side for objective creation","ERROR",true] call omtk_log;
			};
		};
		
		if (_type == "FLAG") then {
			{
				_omtk_sb_flags	set [_x select 0, _x select 1];
			} forEach _values;
		};
		
		// Timed objectives are created here. They consist of a mix of the regular objectives and a flag objective.
		// The execution of the check is handled by a function on a KK timeout. The execution then saves the result on the flag.
		// The flag is then used when computing the scoreboard to assess the completion of the objective.
		if (_type == "T_INSIDE") then {
			// Initialization of the flag
			_omtk_sb_flags set [_values select 0, false];
			
			// IF statement used to accomodate capzones (duplication of the check, one for each faction)
			if (_side == "BLUEFOR+REDFOR") then {
				// Initialization of the duplicated flag
				_omtk_sb_flags set [_newFlag, false];
				[omtk_timedArea, [_x select 6, West, 1, _x select 5, _values select 0, _x select 3, "BLUEFOR"], (_values select 1)*60] call KK_fnc_setTimeout;
				[omtk_timedArea, [_x select 6, East, 1, _x select 5, _newFlag, _x select 3, "REDFOR"], (_values select 1)*60] call KK_fnc_setTimeout;
			} else {
			
				// [function, [fnc args], time in s] call KK_fnc_setTimeout
				// to understand the args, go check in score_board\library.sqf where the fnc is defined
				[omtk_timedArea, [_x select 6, _x select 1, 1, _x select 5, _values select 0, _x select 3, _side], (_values select 1)*60] call KK_fnc_setTimeout;
			};
		};
		if (_type == "T_OUTSIDE") then {
			_omtk_sb_flags	set [_values select 0, false];
			
			[omtk_timedArea, [_x select 6, _x select 1, 0, _x select 5, _values select 0, _x select 3, _side], (_values select 1)*60] call KK_fnc_setTimeout;
		};
		if (_type == "T_SURVIVAL") then {
			_omtk_sb_flags	set [_values select 0, false];
			// _x select 5 = mode+values
			[omtk_timedAlive, [_x select 5, _x select 1, 1, _values select 0, _x select 3, _side], (_values select 1)*60] call KK_fnc_setTimeout;
		};
		if (_type == "T_DESTRUCTION") then {
			_omtk_sb_flags	set [_values select 0, false];
			
			[omtk_timedAlive, [_x select 5, _x select 1, 0, _values select 0, _x select 3, _side], (_values select 1)*60] call KK_fnc_setTimeout;
		};
		
	} foreach OMTK_SB_LIST_OBJECTIFS;
	
	missionNamespace setVariable ["omtk_sb_objectives", _omtk_sb_objectives];
	missionNamespace setVariable ["omtk_sb_scores", _omtk_sb_scores];
	missionNamespace setVariable ["omtk_sb_flags", _omtk_sb_flags];
	
	publicVariable "omtk_sb_scores";
	publicVariable "omtk_sb_objectives";
	publicVariable "omtk_sb_flags";
	
	missionNamespace setVariable ["omtk_sb_ready4result", 0];
	publicVariable "omtk_sb_ready4result";
};



if (hasInterface) then {
	// Display end mission time to client
	sleep 2;
	_omtk_mEnd = missionNamespace getVariable "omtk_mission_end_time_txt";

	if (!isNil "_omtk_mEnd") then {
		[_omtk_mEnd,0,0,10,2] spawn BIS_fnc_dynamicText;
	};
	
	sleep 10;

	_omtk_sb_objectives = missionNamespace getVariable "omtk_sb_objectives";

	_index = -1;
	{
		_index = _index + 1;
		_side = _x select 1;
		_type = _x select 2;
	
		if (side player == _side) then {
			switch(_type) do {
				case "ACTION":	{
					_tgt = _x select 4;
					_tgtType = typeName _tgt;
					if (_tgtType == "STRING") then {
						_tgt = missionNamespace getVariable [_tgt, nil];
					};
					_txt = "<t color='#0000FF'>" + (_x select 3) + "</t>";
					_dur = _x select 5;
					_ext = _x select 6;	
					_action = _tgt addAction[_txt, { call omtk_closeAction;}, [_dur, _ext, _index]];
				};
	
				case "ACTION_DISPUTEE":	{
				
				};
			};
		};
	} foreach _omtk_sb_objectives;

};

["score_boards end", "DEBUG", false] call omtk_log;
