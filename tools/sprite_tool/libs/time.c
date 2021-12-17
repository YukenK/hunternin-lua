#include <stdio.h>
#include "time.h"

#include "lua5.1/lua.h"
#include "lua5.1/lauxlib.h"
int last_time;

int epoch_time() {
	struct timespec ts;
	timespec_get(&ts, TIME_UTC);
	return (ts.tv_sec * 1000) + (ts.tv_nsec / 1000000);
}

int get_time(lua_State *L) {
	lua_pushinteger(L, epoch_time());
	return 1;
}
int delta_time(lua_State *L) {
	int current_time = epoch_time();
	int delta = current_time - last_time;
	last_time = current_time;
	lua_pushinteger(L, delta);
	return 1;
}
static const struct luaL_Reg functions[] = {
	{"get_time", get_time},
	{"delta_time", delta_time},
	{NULL, NULL}
};

int luaopen_libs_time(lua_State *L) {
	last_time = epoch_time();
	luaL_register(L, "time", functions);
	return 1;
}
