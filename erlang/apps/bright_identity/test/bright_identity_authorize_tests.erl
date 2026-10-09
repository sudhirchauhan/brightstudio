-module(bright_identity_authorize_tests).
-include_lib("eunit/include/eunit.hrl").

owner_authorization_test_() ->
    Owner = #{id => <<"owner-1">>, status => active},
    Resource = #{owner_id => <<"owner-1">>},
    [
      ?_assertEqual(ok, bright_identity_authorize:owner(Owner, Resource)),
      ?_assertEqual(ok, bright_identity_authorize:owner(Owner, Resource, write)),
      ?_assertEqual(ok, bright_identity_authorize:owner(Owner, Resource, delete)),
      ?_assertEqual({error, forbidden},
                    bright_identity_authorize:owner(#{id => <<"other">>, status => active}, Resource)),
      ?_assertEqual({error, forbidden},
                    bright_identity_authorize:owner(Owner, #{owner_id => <<"other">>})),
      ?_assertEqual({error, forbidden},
                    bright_identity_authorize:owner(Owner#{status => disabled}, Resource)),
      ?_assertEqual({error, forbidden},
                    bright_identity_authorize:owner(#{id => <<"owner-1">>}, Resource)),
      ?_assertEqual({error, forbidden},
                    bright_identity_authorize:owner(Owner, #{})),
      ?_assertEqual({error, forbidden},
                    bright_identity_authorize:owner(Owner, Resource, admin)),
      ?_assertEqual({error, forbidden},
                    bright_identity_authorize:owner(#{id => <<>>, status => active}, Resource))
    ].
