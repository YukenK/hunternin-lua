#include "time.h"
#include "lua5.1/lua.h"
#include "lua5.1/lauxlib.h"

int epoch_time() {
	struct timespec ts;
	timespec_get(&ts, TIME_UTC);
	return (ts.tv_sec * 1000) + (ts.tv_nsec / 1000000);
}

int get_time(lua_State *L) {
	lua_pushinteger(L, epoch_time());
	return 1;
}
static const struct luaL_Reg functions[] = {
	{"get_time", get_time},
	{NULL, NULL}
};

int luaopen_time(lua_State *L) {
	luaL_register(L, "time", functions);
	return 1;
}
