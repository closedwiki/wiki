/*
 * Copyright (C) 2004 WindRiver Ltd.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details, published at 
 * http://www.gnu.org/copyleft/gpl.html
 */
#ifndef _DAV_TWIKI_H_
#define _DAV_TWIKI_H_

#ifdef __cplusplus
extern "C" {
#endif

extern int dav_twiki_setDBpath(const char* dbname);
extern int dav_twiki_accessible(const request_rec* r,
								const dav_resource* dr, int tgt);
#define TWIKI_NOTYPE 0
/* .../data */
#define TWIKI_DATA 1
/* .../pub */
#define TWIKI_PUB  2

/* anything above DATA|WEB is strange */
/* anything above PUB|TOPIC is strange */

const char* dav_twiki_tostring(const dav_resource* r);
dav_error* dav_twiki_delete(const dav_resource* r);
dav_error* dav_twiki_commit(const dav_resource* r, const char* path);

#ifdef __cplusplus
}
#endif

#endif /* _DAV_TWIKI_H_ */
