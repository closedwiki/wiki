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
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>

#ifdef SDBM
#include "sdbm/sdbm.h"
#define DBM_OPEN(_f,_m,_fl); sdbm_openN((_f), (_m), (_p));
#define DBM_CLOSE(_db) sdbm_close(_db)
#define DBM_FETCH(_k,_d) sdbm_fetch((_k),(_d))
#define DBM_DATUM datum
#define DBM_FIRSTKEY(db) sdbm_firstkey(db)
#define DBM_NEXTKEY(db,d) sdbm_nextkey(db)
#define DBM_FREE(x)
#else
#include <tdb.h>
#define DBM TDB_CONTEXT
#define DBM_OPEN(_f,_m,_p) tdb_open((_f),0,TDB_DEFAULT,(_m),(_p))
#define DBM_CLOSE(_db) tdb_close(_db)
#define DBM_FETCH(_k,_d) tdb_fetch((_k),(_d))
#define DBM_FIRSTKEY(db) tdb_firstkey(db)
#define DBM_NEXTKEY(db,d) tdb_nextkey(db,d)
#define DBM_DATUM TDB_DATA
#define DBM_FREE(x) (x).dptr ? free((x).dptr) : 0
#define DBM_ERROR(_db) tdb_error(_d)
#endif

/*
 * C interface to TWiki protections database.
 */
static char dbfile[512];

static int barred(char* path, const char* mode, const char* user,
				  DBM* db);
static DBM_DATUM getKey(const char* path, const char* ad,
						  DBM* db);
static int isInList(DBM_DATUM list, const char* user,
					DBM* db, int depth);
static int isInGroup(const char* group, const char*user,
					 DBM* db, int depth);
static int isAccessible(DBM* db, const char* web, const char* topic,
						const char* mode, const char* user);

#ifdef PROT_PRINT
static char dumpdata[255];

static char* dump(DBM_DATUM d) {
  strncpy(dumpdata, d.dptr, d.dsize);
  dumpdata[d.dsize] = 0;
  return dumpdata;
}
#endif

/**
 * Define where the lock database is
 */
int PROT_setDBpath(const char* dbname) {
  strcpy(dbfile, dbname);
  strcat(dbfile, "/TWiki");
  return 1;
}

/**
 * Main interface to permissions database. KISS.
 */
int PROT_accessible(const char* web, const char* topic,
			   const char* mode, const char* user) {
  DBM* db = NULL;
#ifdef PROT_PRINT
  DBM_DATUM d;
#endif
  int ret;

  if (mode == NULL)
	return 1;

  db = DBM_OPEN(dbfile, O_RDONLY, 0);

  if (db == NULL) {
	/* No DB, access is permitted */
#ifdef PROT_PRINT
	fprintf(stderr, "Can't open %s: %s\n", dbfile, strerror(errno));
#endif
	return 1;
  }

#ifdef PROT_PRINT
  fprintf(stderr, "<DB %s>\n", dbfile);
  d = DBM_FIRSTKEY(db);
  while(d.dptr && d.dsize) {
	fprintf(stderr,"\tKey %s\n", dump(d));
	d = DBM_NEXTKEY(db,d);
  }
  fprintf(stderr, "</DB>\n");
#endif

  ret = isAccessible(db, web, topic, mode, user);
  DBM_CLOSE(db);

  return ret;
}

static int isAccessible(DBM* db, const char* web, const char* topic,
						const char* mode, const char* user) {
  char path[255];

#ifdef PROT_PRINT
  fprintf(stderr, "AllCheck %s/%s:%s for %s\n",web,topic,mode,user);
#endif

  strcpy(path, "P:/");
  if (barred(path, mode, user, db))
	return 0;

  if (web) {
	sprintf(path, "P:/%s/", web);
#ifdef PROT_PRINT
	fprintf(stderr, "WebCheck %s/%s:%s for %s\n",web,topic,mode,user);
#endif
	if (barred(path, mode, user, db))
	  return 0;
  }

  if (web && topic) {
	sprintf(path, "P:/%s/%s", web, topic);
#ifdef PROT_PRINT
	fprintf(stderr, "TopicCheck %s/%s:%s for %s\n",web,topic,mode,user);
#endif
	if (barred(path, mode, user, db))
	  return 0;
  }

#ifdef PROT_PRINT
  fprintf(stderr, "%s/%s:%s for %s is accessible\n",web,topic,mode,user);
#endif
  return 1;
}

static int barred(char* path, const char* mode, const char* user,
		   DBM* db) {
  DBM_DATUM list;

  strcat(path, ":");
  strcat(path, mode);
  strcat(path, ":");

  /* Paranoia; deny before allow */
  if (user) {
	list = getKey(path, "D", db);
#ifdef PROT_PRINT
	fprintf(stderr,"\t%sD => %s\n", path, dump(list));
#endif
	if (list.dptr) {
	  /* user must not be in deny list */
	  if (isInList(list, user, db, 0)) {
		DBM_FREE(list);
		return 1;
	  }
	  DBM_FREE(list);
	}
  }

  list = getKey(path, "A", db);
#ifdef PROT_PRINT
  fprintf(stderr,"\t%sA => %s\n", path, dump(list));
#endif
  if (list.dptr) {
	/* user must be in good list */
	if (user == NULL || !isInList(list, user, db, 0)) {
	  DBM_FREE(list);
	  return 1;
	}
	DBM_FREE(list);
  }

  return 0;
}

static DBM_DATUM getKey(const char* path, const char* ad, DBM* db) {
  char keyn[255];
  DBM_DATUM key;

  strcpy(keyn, path);
  strcat(keyn, ad);

  key.dptr = keyn;
  key.dsize = strlen(keyn);
  return DBM_FETCH(db, key);
}

/**
 * Determine if the user is in the given group. Note that there is
 * a risk the the group is cyclically defined, so we end up opening
 * a group we are already in. To avoid that risk we maintain a count
 * of the number of groups opened, and will give up if it reaches 100
 */
static int isInGroup(const char* group, const char*user, DBM* db, int depth) {
  DBM_DATUM expanded;
  int ret;

  if (depth > 99) {
	fprintf(stderr, "Infinite cycle in TWiki group %s\n", group);
	return 0;
  }

  expanded = getKey("G:", group, db);
#ifdef PROT_PRINT
  fprintf(stderr,"\tG:%s => %s\n", group, dump(expanded));
#endif
  ret = 0;
  if (expanded.dptr) {
	ret = isInList(expanded, user, db, depth);
	DBM_FREE(expanded);
  }
  return ret;
}

static int isInList(DBM_DATUM list, const char* user, DBM* db, int depth) {
  const char* start = list.dptr;
  const char* stop = list.dptr + list.dsize;
  const char* end;

  while (start != stop) {
	start++; /* skip the | */
	end = start;
	while (end != stop && *end != '|')
	  end++;
	if (!*end)
	  return 0;
	if (end != start && strncmp(start, user, end - start) == 0) {
	  return 1;
	}
	if (strncmp(start + (end - start - 5), "Group", 5) == 0) {
	  char group[end - start + 1];
	  strncpy(group, start, end - start);
	  group[end - start] = '\0';
	  if (isInGroup(group, user, db, depth + 1)) {
		return 1;
	  }
	}
	start = end;
  }
  return 0;
}

