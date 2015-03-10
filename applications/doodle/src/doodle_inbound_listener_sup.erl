%%%-------------------------------------------------------------------
%%% @copyright (C) 2013, 2600Hz
%%% @doc
%%%
%%% @end
%%% @contributors
%%%-------------------------------------------------------------------
-module(doodle_inbound_listener_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-include("doodle.hrl").

-define(JSON(Proplist), {Proplist}).

-define(DEFAULT_EXCHANGE, <<"sms">>).
-define(DEFAULT_EXCHANGE_TYPE, <<"topic">>).
-define(DEFAULT_EXCHANGE_OPTIONS, [{'passive', 'true'}] ).
-define(DEFAULT_EXCHANGE_OPTIONS_JOBJ, ?JSON(?DEFAULT_EXCHANGE_OPTIONS) ).

-define(DEFAULT_BROKER, wh_amqp_connections:primary_broker()).
-define(QUEUE_NAME, <<"smsc_inbound_queue_", (?DOODLE_INBOUND_EXCHANGE)/binary>>).

-define(DOODLE_INBOUND_QUEUE, whapps_config:get_ne_binary(?CONFIG_CAT, <<"inbound_queue_name">>, ?QUEUE_NAME)).
-define(DOODLE_INBOUND_BROKER, whapps_config:get_ne_binary(?CONFIG_CAT, <<"inbound_broker">>, ?DEFAULT_BROKER)).
-define(DOODLE_INBOUND_EXCHANGE, whapps_config:get_ne_binary(?CONFIG_CAT, <<"inbound_exchange">>, ?DEFAULT_EXCHANGE)).
-define(DOODLE_INBOUND_EXCHANGE_TYPE, whapps_config:get_ne_binary(?CONFIG_CAT, <<"inbound_exchange_type">>, ?DEFAULT_EXCHANGE_TYPE)).
-define(DOODLE_INBOUND_EXCHANGE_OPTIONS,  whapps_config:get(?CONFIG_CAT, <<"inbound_exchange_options">>, ?DEFAULT_EXCHANGE_OPTIONS)).


-define(ATOM(A), wh_util:to_atom(A, 'true')).
-define(CHILD_NAME, ?ATOM(wh_util:rand_hex_binary(16))).

-define(CHILDREN, [?WORKER_NAME_ARGS('doodle_inbound_listener', ?CHILD_NAME, [C]) 
                     || #amqp_listener_connection{}=C <- connections()
                  ]).

%% ===================================================================
%% API functions
%% ===================================================================

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Starts the supervisor
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> startlink_ret().
start_link() ->
    supervisor:start_link({'local', ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%% @end
%%--------------------------------------------------------------------
-spec init([]) -> sup_init_ret().
init([]) ->
    wh_util:set_startup(),
    RestartStrategy = 'one_for_one',
    MaxRestarts = 5,
    MaxSecondsBetweenRestarts = 10,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},
    {'ok', {SupFlags, ?CHILDREN}}.

-spec default_connection() -> amqp_listener_connection().
default_connection() ->
    #amqp_listener_connection{name = <<"default">>
                              ,broker = ?DOODLE_INBOUND_BROKER
                              ,exchange = ?DOODLE_INBOUND_EXCHANGE
                              ,type = ?DOODLE_INBOUND_EXCHANGE_TYPE
                              ,queue = ?DOODLE_INBOUND_QUEUE
                              ,options = wh_json:to_proplist(?DEFAULT_EXCHANGE_OPTIONS_JOBJ)  
                             }.

-spec connections() -> amqp_listener_connections().
connections() ->
    case whapps_config:get(?CONFIG_CAT, <<"connections">>) of
        'undefined' -> [default_connection()];
        JObj -> wh_json:foldl(fun connections_fold/3, [], JObj)
    end.

-spec connections_fold(binary(), term(), wh_proplist()) -> amqp_listener_connection().
connections_fold(K, V, Acc) ->
    C = #amqp_listener_connection{name = K
                              ,broker = wh_json:get_value(<<"broker">>, V) 
                              ,exchange = wh_json:get_value(<<"exchange">>, V) 
                              ,type = wh_json:get_value(<<"type">>, V) 
                              ,queue = wh_json:get_value(<<"queue">>, V) 
                              ,options = connection_options(wh_json:get_value(<<"options">>, V)) 
                              },
    [ C | Acc].

-spec connection_options(api_object()) -> wh_proplist().
connection_options('undefined') -> ?DEFAULT_EXCHANGE_OPTIONS;
connection_options(JObj) ->
    [ {wh_util:to_atom(K, 'true'), V} || {K, V} <- wh_json:to_proplist(JObj) ].
    
