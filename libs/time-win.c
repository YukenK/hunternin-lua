#include "time.h"
#include "lua.h"
#include "lauxlib.h"
#include <windows.h>

#define EXPORT __declspec(dllexport)

EXPORT int epoch_time() {
	FILETIME ft;
	LARGE_INTEGER li;
	GetSystemTimeAsFileTime(&ft);
	li.LowPart = ft.dwLowDateTime;
	li.HighPart = ft.dwHighDateTime;
	return li.QuadPart / 10000;
}

EXPORT int get_time(lua_State *L) {
	lua_pushinteger(L, epoch_time());
	return 1;
}
static const struct luaL_Reg functions[] = {
	{"get_time", get_time},
	{NULL, NULL}
};

EXPORT int luaopen_libs_time(lua_State *L) {
	luaL_register(L, "time", functions);
	return 1;
}
