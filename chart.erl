-module(chart).

-record(chart, { %% 通用排行结构
	key_fun,		%% 键函数
	value_fun,		%% 值函数
	rank_fun,		%% 添加名次函数
	small_value,	%% 上榜最小值
	num,			%% 上榜数量
	key_list = [],			%% 已排序的列表
	bin_dict = dict:new()	%% 需排行的字典
}).

%% API
-export([
	new/5, insert/2, delete/2, refresh/1, clear/1, list/1, element/3
]).

%% 创建新排行榜
new(KeyFun, ValueFun, RankFun, SmallValue, Num) ->
	#chart{
		key_fun = KeyFun,
		value_fun = ValueFun,
		rank_fun = RankFun,
		small_value = SmallValue,
		num = Num
	}
.

%% 添加元素
insert(E, Chart) ->
	KeyFun = Chart#chart.key_fun,
	Key = KeyFun(E),
	BinDict = Chart#chart.bin_dict,
	NewBinDict = dict:store(Key, E, BinDict),
	Chart#chart{bin_dict = NewBinDict}
.

%% 删除元素
delete(E, Chart) ->
	KeyFun = Chart#chart.key_fun,
	Key = KeyFun(E),
	BinDict = Chart#chart.bin_dict,
	NewBinDict = dict:erase(Key, BinDict),
	Chart#chart{bin_dict = NewBinDict}
.

%% 刷新排行榜
refresh(Chart) ->
	ValueFun = Chart#chart.value_fun,
	Num = Chart#chart.num,
	BinDict = Chart#chart.bin_dict,
	SmallValue = Chart#chart.small_value,
	{_, GbSets} = dict:fold(
		fun(K, E, {S, GS}) ->
			Value = {ValueFun(E), K},
			case Value > S of
				false ->
					{S, GS};
				true ->
					case gb_sets:size(GS) of
						Num ->
							{_, GS0} = gb_sets:take_smallest(GS),
							NewGS = gb_sets:add(Value, GS0),
							{gb_sets:smallest(NewGS), NewGS};
						_ ->
							{S, gb_sets:add(Value, GS)}
					end
			end
		end, {{SmallValue, 0}, gb_sets:empty()}, BinDict),
	RankFun = Chart#chart.rank_fun,
	{_, NewKeyList, NewBinDict} = lists:foldl(
		fun({_, Key}, {N, L, D}) ->
			{N - 1, [Key | L], dict:update(Key, fun(E) -> RankFun(E, N) end, D)}
		end, {gb_sets:size(GbSets), [], BinDict}, gb_sets:to_list(GbSets)),
	Chart#chart{
		key_list = NewKeyList,
		bin_dict = NewBinDict
	}
.

%% 清除排行榜数据
clear(Chart) ->
	Chart#chart{
		key_list = [],
		bin_dict = dict:new()
	}
.

%% 获取排行榜
list(Chart) ->
	KeyList = Chart#chart.key_list,
	BinDict = Chart#chart.bin_dict,
	[dict:fetch(Key, BinDict) || Key <- KeyList]
.

%% 获取元素，找不到返回默认值
element(Key, Chart, Default) ->
	case dict:find(Key, Chart#chart.bin_dict) of
		error -> Default;
		{ok, Element} -> Element
	end
.
