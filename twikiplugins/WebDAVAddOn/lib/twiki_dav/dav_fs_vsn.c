/*
** Copyright (C) 2004 Wind River Systems Inc.
**
** Interface to versioning operations
*/
#include "httpd.h"
#include "http_log.h"

#include "mod_dav.h"
#include "dav_fs_repos.h"

extern const dav_hooks_vsn dav_hooks_vsn_fs;

/*
 * Return supported versioning level for the Versioning header
 */
static const char * dav_fs_get_vsn_header(void) {
    return "version-control,checkout,checkin,uncheckout";
}

/* Create a new (empty) resource. If successful,
 * the resource object state is updated appropriately.
 */
static dav_error * dav_fs_mkresource(dav_resource *resource)
{
    const char *dirpath;
	pool* p;

    dav_fs_dir_file_name(resource, &dirpath, NULL);
    p = dav_fs_pool(resource);
    return dav_new_error(p,
			 HTTP_BAD_REQUEST,
			 0,
			 ap_psprintf(p, "MkResource %s", dirpath));
    /* TODO: need to update resource object state */
}

/* Checkout a resource. If successful, the resource
 * object state is updated appropriately.
 */
static dav_error * dav_fs_checkout(dav_resource *resource) {

    /*logEvent("FS_CHECKOUT ", resource);*/
    /* working is supposed to be the revision number of the working
     * revision, but I'm cheating here and simply using it as a
     * semaphore to ensure the rest of mod_dav understands that this
     * file is checked out. */
    resource->working = 1;
    return NULL;
}

/* Uncheckout a resource. If successful, the resource
 * object state is updated appropriately.
 */
static dav_error * dav_fs_uncheckout(dav_resource *resource)
{
    /*logEvent("FS_UNCHECKOUT ", resource);*/
    resource->working = 0;

    return NULL;
}

/* Checkin a working resource. If successful, the resource
 * object state is updated appropriately.
 */
static dav_error * dav_fs_checkin(dav_resource *resource)
{
  /* logEvent("FS_CHECKIN ", resource);*/
  twiki_resources* tr = resource->twiki;
  pool* p = dav_fs_pool(resource);
  const char* cmd = ap_psprintf(p,
								"%s commit %s %s %s %s",
								tr->script,
								tr->web,
								tr->topic,
								tr->file,
								tr->user ? tr->user : "guest");

  /*fprintf(stderr, "%s\n", cmd);*/

  /* Wait for process to finish. Dangerous? Maybe. */
  int e = system(cmd);
  if (e) {
	return dav_new_error(p,
						 HTTP_FORBIDDEN,
						 0,
						 ap_psprintf(p, "%s ext code %d",
									 cmd,
									 e));
  }

  /* release the resource */
  resource->working = 0;

  return NULL;
}

/* Determine whether a non-versioned (or non-existent) resource
 * is versionable. Returns != 0 if resource can be versioned.
 */
static int dav_fs_versionable(const dav_resource *resource)
{
    /* Assume twiki resources can always be versioned just now */
    return (resource->twiki != NULL);
}

/* Determine whether auto-versioning is enabled for a resource
 * (which may not exist, or may not be versioned).
 * Returns != 0 if auto-versioning is enabled.
 */
static int dav_fs_auto_version_enabled(const dav_resource *resource)
{
    /* Assume twiki resources can always be versioned just now */
    return (resource->twiki != NULL);
}

/* Don't actually use all these hooks, just get_vsn_header, checkout,
 * checkin and uncheckout, but implement them all because don't fully
 * understand the protocol (and it's unfinished in this version of
 * mod_dav anyway) */
const dav_hooks_vsn dav_hooks_vsn_fs = {
    &dav_fs_get_vsn_header,
    &dav_fs_mkresource,
    &dav_fs_checkout,
    &dav_fs_uncheckout,
    &dav_fs_checkin,
    &dav_fs_versionable,
    &dav_fs_auto_version_enabled
};
