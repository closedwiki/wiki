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

#ifdef SDBM
#include "sdbm/sdbm.h"
#define DBM_OPENN(_f,_m,_fl); sdbm_openN((_f), (_m), (_p));
#define DBM_CLOSE(_db) sdbm_close(_db)
#define DBM_FETCH(_k,_d) sdbm_fetch((_k),(_d))
#define DATUM datum
#define FIRSTKEY(db) sdbm_firstkey(db)
#define NEXTKEY(db,d) sdbm_nextkey(db)
#define FREEDATUM(x)
#else
#include <tdb.h>
#define DBM TDB_CONTEXT
#define DBM_OPEN(_f,_m,_p) tdb_open((_f),0,TDB_DEFAULT,(_m),(_p))
#define DBM_CLOSE(_db) tdb_close(_db)
#define DBM_FETCH(_k,_d) tdb_fetch((_k),(_d))
#define FIRSTKEY(db) tdb_firstkey(db)
#define NEXTKEY(db,d) tdb_nextkey(db,d)
#define DATUM TDB_DATA
#define FREEDATUM(x) (x).dptr ? free((x).dptr) : 0
#endif

/*
 * C interface to TWiki protections database.
 */
static char dbfile[512];

static int barred(char* path, const char* mode, const char* user,
				  DBM* db);
static DATUM getKey(const char* path, const char* ad,
						  DBM* db);
static int isInList(DATUM list, const char* user,
					DBM* db, int depth);
static int isInGroup(const char* group, const char*user,
					 DBM* db, int depth);
static int isAccessible(DBM* db, const char* web, const char* topic,
						const char* mode, const char* user);

#ifdef PROT_PRINT
static char dumpdata[255];

static char* dump(DATUM d) {
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
  int ret;

  if (mode == NULL)
	return 1;

  db = DBM_OPEN(dbfile, O_RDONLY, 0);

  if (db == NULL) {
	/* No DB, access is permitted */
#ifdef PROT_PRINT
	fprintf(stderr, "Can't open %s\n", dbfile);
#endif
	return 1;
  }

#ifdef PROT_PRINT
  fprintf(stderr, "<DB %s>\n", dbfile);
  DATUM d = FIRSTKEY(db);
  while(d.dptr && d.dsize) {
	fprintf(stderr,"\tKey %s\n", dump(d));
	d = NEXTKEY(db,d);
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
  DATUM list;

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
		FREEDATUM(list);
		return 1;
	  }
	  FREEDATUM(list);
	}
  }

  list = getKey(path, "A", db);
#ifdef PROT_PRINT
  fprintf(stderr,"\t%sA => %s\n", path, dump(list));
#endif
  if (list.dptr) {
	/* user must be in good list */
	if (user == NULL || !isInList(list, user, db, 0)) {
	  FREEDATUM(list);
	  return 1;
	}
	FREEDATUM(list);
  }

  return 0;
}

static DATUM getKey(const char* path, const char* ad, DBM* db) {
  char keyn[255];
  DATUM key;

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
  DATUM expanded;

  if (depth > 99) {
	fprintf(stderr, "Infinite cycle in TWiki group %s\n", group);
	return 0;
  }

  expanded = getKey("G:", group, db);
#ifdef PROT_PRINT
  fprintf(stderr,"\tG:%s => %s\n", group, dump(expanded));
#endif
  int ret = 0;
  if (expanded.dptr) {
	ret = isInList(expanded, user, db, depth);
	FREEDATUM(expanded);
  }
  return ret;
}

static int isInList(DATUM list, const char* user, DBM* db, int depth) {
  const char* start = list.dptr;
  const char* stop = list.dptr + list.dsize;
  while (start != stop) {
	start++; /* skip the | */
	const char* end = start;
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

