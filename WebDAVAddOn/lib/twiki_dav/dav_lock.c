/*
** Copyright (C) 1998-2000 Greg Stein. All Rights Reserved.
**
** By using this file, you agree to the terms and conditions set forth in
** the LICENSE.html file which can be found at the top level of the mod_dav
** distribution or at http://www.webdav.org/mod_dav/license-1.html.
**
** Contact information:
**   Greg Stein, PO Box 760, Palo Alto, CA, 94302
**   gstein@lyra.org, http://www.webdav.org/mod_dav/
*/

/*
** DAV repository-independent lock functions
**
** Written 06/99 by Keith Wannamaker, wannamak@us.ibm.com
**
** Modified 08/99 by John Vasta, vasta@rational.com, to move filesystem-based
** implementation to dav_fs_lock.c
*/

#include "mod_dav.h"
#include "http_log.h"
#include "http_config.h"
#include "http_protocol.h"
#include "http_core.h"
#include "memory.h"


/* ---------------------------------------------------------------
**
** Property-related lock functions
**
*/

/*
** dav_lock_get_activelock:  Returns a <lockdiscovery> containing
**    an activelock element for every item in the lock_discovery tree
*/
const char *dav_lock_get_activelock(request_rec *r, dav_lock *lock,
				    dav_buffer *pbuf)
{
    dav_lock *lock_scan;
    const dav_hooks_locks *hooks = DAV_GET_HOOKS_LOCKS(r);
    int count = 0;
    dav_buffer work_buf = { 0 };
    pool *p = r->pool;

    /* If no locks or no lock provider, there are no locks */
    if (lock == NULL || hooks == NULL) {
	/*
	** Since resourcediscovery is defined with (activelock)*, 
	** <D:activelock/> shouldn't be necessary for an empty lock.
	*/
	return "";
    }

    /*
    ** Note: it could be interesting to sum the lengths of the owners
    **       and locktokens during this loop. However, the buffer
    **       mechanism provides some rough padding so that we don't
    **       really need to have an exact size. Further, constructing
    **       locktoken strings could be relatively expensive.
    */
    for (lock_scan = lock; lock_scan != NULL; lock_scan = lock_scan->next)
	count++;

    /* if a buffer was not provided, then use an internal buffer */
    if (pbuf == NULL)
	pbuf = &work_buf;

    /* reset the length before we start appending stuff */
    pbuf->cur_len = 0;

    /* prep the buffer with a "good" size */
    dav_check_bufsize(p, pbuf, count * 300);

    for (; lock != NULL; lock = lock->next) {
	char tmp[100];

#if DAV_DEBUG
	if (lock->rectype == DAV_LOCKREC_INDIRECT_PARTIAL) {
	    /* ### crap. design error */
	    dav_buffer_append(p, pbuf,
			      "DESIGN ERROR: attempted to product an "
			      "activelock element from a partial, indirect "
			      "lock record. Creating an XML parsing error "
			      "to ease detection of this situation: <");
	}
#endif

	dav_buffer_append(p, pbuf, "<D:activelock>" DEBUG_CR "<D:locktype>");
	switch (lock->type) {
	case DAV_LOCKTYPE_WRITE:
	    dav_buffer_append(p, pbuf, "<D:write/>");
	    break;
	default:
	    /* ### internal error. log something? */
	    break;
	}
	dav_buffer_append(p, pbuf, "</D:locktype>" DEBUG_CR "<D:lockscope>");
	switch (lock->scope) {
	case DAV_LOCKSCOPE_EXCLUSIVE:
	    dav_buffer_append(p, pbuf, "<D:exclusive/>");
	    break;
	case DAV_LOCKSCOPE_SHARED:
	    dav_buffer_append(p, pbuf, "<D:shared/>");
	    break;
	default:
	    /* ### internal error. log something? */
	    break;
	}
	dav_buffer_append(p, pbuf, "</D:lockscope>" DEBUG_CR);
	sprintf(tmp, "<D:depth>%s</D:depth>" DEBUG_CR,
		lock->depth == DAV_INFINITY ? "infinity" : "0");
	dav_buffer_append(p, pbuf, tmp);

	if (lock->owner) {
	    /*
	    ** This contains a complete, self-contained <DAV:owner> element,
	    ** with namespace declarations and xml:lang handling. Just drop
	    ** it in.
	    */
	    dav_buffer_append(p, pbuf, lock->owner);
	}
		
	dav_buffer_append(p, pbuf, "<D:timeout>");
	if (lock->timeout == DAV_TIMEOUT_INFINITE) {
	    dav_buffer_append(p, pbuf, "Infinite");
	}
	else {
	    time_t now = time(NULL);
	    sprintf(tmp, "Second-%lu", lock->timeout - now);
	    dav_buffer_append(p, pbuf, tmp);
	}

	dav_buffer_append(p, pbuf,
			  "</D:timeout>" DEBUG_CR
			  "<D:locktoken>" DEBUG_CR
			  "<D:href>");
	dav_buffer_append(p, pbuf,
			  (*hooks->format_locktoken)(p, lock->locktoken));
	dav_buffer_append(p, pbuf,
			  "</D:href>" DEBUG_CR
			  "</D:locktoken>" DEBUG_CR
			  "</D:activelock>" DEBUG_CR);
    }

    return pbuf->buf;
}

/*
** dav_lock_parse_lockinfo:  Validates the given xml_doc to contain a
**    lockinfo XML element, then populates a dav_lock structure
**    with its contents.
*/
dav_error * dav_lock_parse_lockinfo(request_rec *r,
				    const dav_resource *resource,
				    dav_lockdb *lockdb,
				    const dav_xml_doc *doc,
				    dav_lock **lock_request)
{
    const dav_hooks_locks *hooks = DAV_GET_HOOKS_LOCKS(r);
    pool *p = r->pool;
    dav_error *err;
    dav_xml_elem *child;
    dav_lock *lock;
	
    if (!dav_validate_root(doc, "lockinfo")) {
	return dav_new_error(p, HTTP_BAD_REQUEST, 0,
			     "The request body contains an unexpected "
			     "XML root element.");
    }

    if ((err = (*hooks->create_lock)(lockdb, resource, &lock)) != NULL) {
	return dav_push_error(p, err->status, 0,
			      "Could not parse the lockinfo due to an "
			      "internal problem creating a lock structure.",
			      err);
    }

    lock->depth = dav_get_depth(r, DAV_INFINITY);
    if (lock->depth == -1) {
	return dav_new_error(p, HTTP_BAD_REQUEST, 0,
			     "An invalid Depth header was specified.");
    }
    lock->timeout = dav_get_timeout(r);

    /* Parse elements in the XML body */
    for (child = doc->root->first_child; child; child = child->next) {
	if (strcmp(child->name, "locktype") == 0
	    && child->first_child
	    && lock->type == DAV_LOCKTYPE_UNKNOWN) {
	    if (strcmp(child->first_child->name, "write") == 0) {
		lock->type = DAV_LOCKTYPE_WRITE;
		continue;
	    }
	}
	if (strcmp(child->name, "lockscope") == 0
	    && child->first_child
	    && lock->scope == DAV_LOCKSCOPE_UNKNOWN) {
	    if (strcmp(child->first_child->name, "exclusive") == 0)
		lock->scope = DAV_LOCKSCOPE_EXCLUSIVE;
	    else if (strcmp(child->first_child->name, "shared") == 0)
		lock->scope = DAV_LOCKSCOPE_SHARED;
	    if (lock->scope != DAV_LOCKSCOPE_UNKNOWN)
		continue;
	}

	if (strcmp(child->name, "owner") == 0 && lock->owner == NULL) {
	    const char *text;

	    /* quote all the values in the <DAV:owner> element */
	    dav_quote_xml_elem(p, child);

	    /*
	    ** Store a full <DAV:owner> element with namespace definitions
	    ** and an xml:lang definition, if applicable.
	    */
	    dav_xml2text(p, child, DAV_X2T_FULL_NS_LANG, doc->namespaces, NULL,
			 &text, NULL);
	    lock->owner = text;

	    continue;
	}

	return dav_new_error(p, HTTP_PRECONDITION_FAILED, 0,
			     ap_psprintf(p,
					 "The server cannot satisfy the "
					 "LOCK request due to an unknown XML "
					 "element (\"%s\") within the "
					 "DAV:lockinfo element.",
					 child->name));
    }

    *lock_request = lock;
    return NULL;
}

/* ---------------------------------------------------------------
**
** General lock functions
**
*/

/* dav_lock_walker:  Walker callback function to record indirect locks */
static dav_error * dav_lock_walker(dav_walker_ctx *ctx, int calltype)
{
    dav_error *err;

    /* We don't want to set indirects on the target */
    if ((*ctx->resource->hooks->is_same_resource)(ctx->resource, ctx->root))
	return NULL;

    if ((err = (*ctx->lockdb->hooks->append_locks)(ctx->lockdb, ctx->resource,
						   1,
						   ctx->lock)) != NULL) {
	if (ap_is_HTTP_SERVER_ERROR(err->status)) {
	    /* ### add a higher-level description? */
	    return err;
	}

	/* add to the multistatus response */
	dav_add_response(ctx, ctx->resource->uri, err->status, NULL);

	/*
	** ### actually, this is probably wrong: we want to fail the whole
	** ### LOCK process if something goes bad. maybe the caller should
	** ### do a dav_unlock() (e.g. a rollback) if any errors occurred.
	*/
    }

    return NULL;
}

/*
** dav_add_lock:  Add a direct lock for resource, and indirect locks for
**    all children, bounded by depth.
**    ### assume request only contains one lock
*/
dav_error * dav_add_lock(request_rec *r, const dav_resource *resource,
			 dav_lockdb *lockdb, dav_lock *lock,
			 dav_response **response)
{
    const dav_hooks_locks *hooks = DAV_GET_HOOKS_LOCKS(r);
    dav_error *err;
    int depth = lock->depth;

    *response = NULL;

    /* Requested lock can be:
     *   Depth: 0   for null resource, existing resource, or existing collection
     *   Depth: Inf for existing collection
     */

    /*
    ** 2518 9.2 says to ignore depth if target is not a collection (it has
    **   no internal children); pretend the client gave the correct depth.
    */
    if (!resource->collection) {
	depth = 0;
    }

    /* In all cases, first add direct entry in lockdb */

    /*
    ** Append the new (direct) lock to the resource's existing locks.
    **
    ** Note: this also handles locknull resources
    */
    if ((err = (*hooks->append_locks)(lockdb, resource, 0, lock)) != NULL) {
	/* ### maybe add a higher-level description */
	return err;
    }

    if (depth > 0) {
	/* Walk existing collection and set indirect locks */
	dav_walker_ctx ctx = { 0 };

	ctx.walk_type = DAV_WALKTYPE_ALL | DAV_WALKTYPE_AUTH;
	ctx.postfix = 0;
	ctx.func = dav_lock_walker;
	ctx.pool = r->pool;
	ctx.r = r;
        ctx.resource = resource;
	ctx.lockdb = lockdb;
	ctx.lock = lock;

	dav_buffer_init(r->pool, &ctx.uri, resource->uri);

	err = (*resource->hooks->walk)(&ctx, DAV_INFINITY);
	if (err != NULL) {
	    /* implies a 5xx status code occurred. screw the multistatus */
	    return err;
	}

	if (ctx.response != NULL) {
	    /* manufacture a 207 error for the multistatus response */
	    *response = ctx.response;
	    return dav_new_error(r->pool, HTTP_MULTI_STATUS, 0,
				 "Error(s) occurred on resources during the "
				 "addition of a depth lock.");
	}
    }

    return NULL;
}

/*
** dav_lock_query:  Opens the lock database. Returns a linked list of
**    dav_lock structures for all direct locks on path.
*/
dav_error * dav_lock_query(dav_lockdb *lockdb, const dav_resource *resource,
			   dav_lock **locks)
{
    /* If no lock database, return empty result */
    if (lockdb == NULL) {
        *locks = NULL;
        return NULL;
    }

    /* ### insert a higher-level description? */
    return (*lockdb->hooks->get_locks)(lockdb, resource,
				       DAV_GETLOCKS_RESOLVED,
				       locks);
}

/* dav_unlock_walker:  Walker callback function to remove indirect locks */
static dav_error * dav_unlock_walker(dav_walker_ctx *ctx, int calltype)
{
    dav_error *err;

    if ((err = (*ctx->lockdb->hooks->remove_lock)(ctx->lockdb, ctx->resource,
						  ctx->locktoken)) != NULL) {
	/* ### should we stop or return a multistatus? looks like STOP */
	/* ### add a higher-level description? */
	return err;
    }

    return NULL;
}

/*
** dav_get_direct_resource:
**
** Find a lock on the specified resource, then return the resource the
** lock was applied to (in other words, given a (possibly) indirect lock,
** return the direct lock's corresponding resource).
**
** If the lock is an indirect lock, this usually means traversing up the
** namespace [repository] hierarchy. Note that some lock providers may be
** able to return this information with a traversal.
*/
static dav_error * dav_get_direct_resource(pool *p,
					   dav_lockdb *lockdb,
					   const dav_locktoken *locktoken,
					   const dav_resource *resource,
					   const dav_resource **direct_resource)
{
    if (lockdb->hooks->lookup_resource != NULL) {
	return (*lockdb->hooks->lookup_resource)(lockdb, locktoken,
						 resource, direct_resource);
    }

    *direct_resource = NULL;

    /* Find the top of this lock-
     * If r->filename's direct   locks include locktoken, use r->filename.
     * If r->filename's indirect locks include locktoken, retry r->filename/..
     * Else fail.
     */
    while (resource != NULL) {
	dav_error *err;
	dav_lock *lock;

	/*
	** Find the lock specified by <locktoken> on <resource>. If it is
	** an indirect lock, then partial results are okay. We're just
	** trying to find the thing and know whether it is a direct or
	** an indirect lock.
	*/
	if ((err = (*lockdb->hooks->find_lock)(lockdb, resource, locktoken,
					       1, &lock)) != NULL) {
	    /* ### add a higher-level desc? */
	    return err;
	}

	/* not found! that's an error. */
	if (lock == NULL) {
	    return dav_new_error(p, HTTP_BAD_REQUEST, 0,
				 "The specified locktoken does not correspond "
				 "to an existing lock on this resource.");
	}

	if (lock->rectype == DAV_LOCKREC_DIRECT) {
	    /* we found the direct lock. return this resource. */

	    *direct_resource = resource;
	    return NULL;
	}

	/* the lock was indirect. move up a level in the URL namespace */
	resource = (*resource->hooks->get_parent_resource)(resource);
    }

    return dav_new_error(p, HTTP_INTERNAL_SERVER_ERROR, 0,
			 "The lock database is corrupt. A direct lock could "
			 "not be found for the corresponding indirect lock "
			 "on this resource.");
}

/*
** dav_unlock:  Removes all direct and indirect locks for r->filename,
**    with given locktoken.  If locktoken == null_locktoken, all locks
**    are removed.  If r->filename represents an indirect lock,
**    we must unlock the appropriate direct lock.
**    Returns OK or appropriate HTTP_* response and logs any errors.
**
** ### We've already crawled the tree to ensure everything was locked
**     by us; there should be no need to incorporate a rollback.
*/
int dav_unlock(request_rec *r, const dav_resource *resource,
	       const dav_locktoken *locktoken)
{
    int result;
    dav_lockdb *lockdb;
    const dav_resource *lock_resource = resource;
    const dav_hooks_locks *hooks = DAV_GET_HOOKS_LOCKS(r);
    const dav_hooks_repository *repos_hooks = resource->hooks;
    dav_error *err;

    /* If no locks provider, we shouldn't have been called */
    if (hooks == NULL) {
	/* ### map result to something nice; log an error */
	return HTTP_INTERNAL_SERVER_ERROR;
    }

    /* 2518 requires the entire lock to be removed if resource/locktoken
     * point to an indirect lock.  We need resource of the _direct_
     * lock in order to walk down the tree and remove the locks.  So,
     * If locktoken != null_locktoken, 
     *    Walk up the resource hierarchy until we see a direct lock.
     *    Or, we could get the direct lock's db/key, pick out the URL
     *    and do a subrequest.  I think walking up is faster and will work
     *    all the time.
     * Else
     *    Just start removing all locks at and below resource.
     */

    if ((err = (*hooks->open_lockdb)(r, 0, 1, &lockdb)) != NULL) {
	/* ### return err! maybe add a higher-level desc */
	/* ### map result to something nice; log an error */
	return HTTP_INTERNAL_SERVER_ERROR;
    }

    if (locktoken != NULL
	&& (err = dav_get_direct_resource(r->pool, lockdb,
					  locktoken, resource,
					  &lock_resource)) != NULL) {
	/* ### add a higher-level desc? */
	/* ### should return err! */
	return err->status;
    }

    /* At this point, lock_resource/locktoken refers to a direct lock (key), ie
     * the root of a depth > 0 lock, or locktoken is null.
     */
    if ((err = (*hooks->remove_lock)(lockdb, lock_resource,
				     locktoken)) != NULL) {
	/* ### add a higher-level desc? */
	/* ### return err! */
	return HTTP_INTERNAL_SERVER_ERROR;
    }

    if (lock_resource->collection) {
	dav_walker_ctx ctx = { 0 };

	ctx.walk_type = DAV_WALKTYPE_ALL | DAV_WALKTYPE_LOCKNULL;
	ctx.postfix = 0;
	ctx.func = dav_unlock_walker;
	ctx.pool = r->pool;
        ctx.resource = lock_resource;
	ctx.r = r;
	ctx.lockdb = lockdb;
	ctx.locktoken = locktoken;

	dav_buffer_init(r->pool, &ctx.uri, lock_resource->uri);

	err = (*repos_hooks->walk)(&ctx, DAV_INFINITY);

	/* ### fix this! */
	result = err == NULL ? OK : err->status;
    }
    else
	result = OK;

    (*hooks->close_lockdb)(lockdb);

    return result;
}

/* dav_inherit_walker:  Walker callback function to inherit locks */
static dav_error * dav_inherit_walker(dav_walker_ctx *ctx, int calltype)
{
    if (ctx->skip_root
	&& (*ctx->resource->hooks->is_same_resource)(ctx->resource,
						     ctx->root)) {
	return NULL;
    }

    /* ### maybe add a higher-level desc */
    return (*ctx->lockdb->hooks->append_locks)(ctx->lockdb, ctx->resource, 1,
					       ctx->lock);
}

/*
** dav_inherit_locks:  When a resource or collection is added to a collection,
**    locks on the collection should be inherited to the resource/collection.
**    (MOVE, MKCOL, etc) Here we propagate any direct or indirect locks from
**    parent of resource to resource and below.
*/
static dav_error * dav_inherit_locks(request_rec *r, dav_lockdb *lockdb,
				     const dav_resource *resource,
				     int use_parent)
{
    dav_error *err;
    const dav_resource *which_resource;
    dav_lock *locks;
    dav_lock *scan;
    dav_lock *prev;
    dav_walker_ctx ctx = { 0 };
    const dav_hooks_repository *repos_hooks = resource->hooks;

    if (use_parent) {
	which_resource = (*repos_hooks->get_parent_resource)(resource);
	if (which_resource == NULL) {
	    /* ### map result to something nice; log an error */
	    return dav_new_error(r->pool, HTTP_INTERNAL_SERVER_ERROR, 0,
				 "Could not fetch parent resource. Unable to "
				 "inherit locks from the parent and apply "
				 "them to this resource.");
	}
    }
    else {
	which_resource = resource;
    }

    if ((err = (*lockdb->hooks->get_locks)(lockdb, which_resource,
					   DAV_GETLOCKS_PARTIAL,
					   &locks)) != NULL) {
	/* ### maybe add a higher-level desc */
	return err;
    }

    if (locks == NULL) {
	/* No locks to propagate, just return */
	return NULL;
    }

    /*
    ** (1) Copy all indirect locks from our parent;
    ** (2) Create indirect locks for the depth infinity, direct locks
    **     in our parent.
    **
    ** The append_locks call in the walker callback will do the indirect
    ** conversion, but we need to remove any direct locks that are NOT
    ** depth "infinity".
    */
    for (scan = locks, prev = NULL;
	 scan != NULL;
	 prev = scan, scan = scan->next) {

	if (scan->rectype == DAV_LOCKREC_DIRECT
	    && scan->depth != DAV_INFINITY) {

	    if (prev == NULL)
		locks = scan->next;
	    else
		prev->next = scan->next;
	}
    }

    /* <locks> has all our new locks.  Walk down and propagate them. */

    ctx.walk_type = DAV_WALKTYPE_ALL | DAV_WALKTYPE_LOCKNULL;
    ctx.postfix = 0;
    ctx.func = dav_inherit_walker;
    ctx.pool = r->pool;
    ctx.resource = resource;
    ctx.r = r;
    ctx.lockdb = lockdb;
    ctx.lock = locks;
    ctx.skip_root = !use_parent;

    dav_buffer_init(r->pool, &ctx.uri, resource->uri);

    return (*repos_hooks->walk)(&ctx, DAV_INFINITY);
}

/* ---------------------------------------------------------------
**
** Functions dealing with lock-null resources
**
*/

/*
** dav_get_resource_state:  Returns the state of the resource
**    r->filename:  DAV_RESOURCE_NULL, DAV_RESOURCE_LOCK_NULL,
**    or DAV_RESOURCE_EXIST.
**
**    Returns DAV_RESOURCE_ERROR if an error occurs.
*/
int dav_get_resource_state(request_rec *r, const dav_resource *resource)
{
    const dav_hooks_locks *hooks = DAV_GET_HOOKS_LOCKS(r);

    if (resource->exists)
	return DAV_RESOURCE_EXISTS;

    if (hooks != NULL) {
	dav_error *err;
	dav_lockdb *lockdb;
	int locks_present;

        /* ### the code below is an optimization to avoid the lock database
           ### in certain cases. however, this doesn't work properly for
           ### the COPY and MOVE case where we are passed the destination.
           ### r->path_info is unrelated to that, so we shouldn't be
           ### checking it.

           ### further, for non-filesystem repositories the path_info will
           ### definitely be non-null.

           ### omit this code. we may reevaluate later.
        */
#if 0
	/*
	** A locknull resource has the form:
	**
	**   known-dir "/" locknull-file
	**
	** It would be nice to look into <resource> to verify this form,
	** but it does not have enough information for us. Instead, we
	** can look at the path_info. If the form does not match, then
	** there is no way we could have a locknull resource -- it must
	** be a plain, null resource.
	**
	** Apache sets r->filename to known-dir/unknown-file and r->path_info
	** to "" for the "proper" case. If anything is in path_info, then
	** it can't be a locknull resource.
	**
	** ### I bet this path_info hack doesn't work for repositories.
	** ### Need input from repository implementors! What kind of
	** ### restructure do we need? New provider APIs?
	*/
	if (r->path_info != NULL && *r->path_info != '\0') {
	    return DAV_RESOURCE_NULL;
	}
#endif
	
        if ((err = (*hooks->open_lockdb)(r, 1, 1, &lockdb)) == NULL) {
	    /* note that we might see some expired locks... *shrug* */
	    err = (*hooks->has_locks)(lockdb, resource, &locks_present);
	    (*hooks->close_lockdb)(lockdb);
        }

        if (err != NULL) {
	    /* ### don't log an error. return err. add higher-level desc. */

	    ap_log_rerror(APLOG_MARK, APLOG_ERR | APLOG_NOERRNO, r,
		          "Failed to query lock-null status for %s",
			  resource->uri);

	    return DAV_RESOURCE_ERROR;
        }

	if (locks_present)
	    return DAV_RESOURCE_LOCK_NULL;
    }

    return DAV_RESOURCE_NULL;
}

dav_error * dav_notify_created(request_rec *r,
			       dav_lockdb *lockdb,
			       const dav_resource *resource,
			       int resource_state,
			       int depth)
{
    dav_error *err;

    if (resource_state == DAV_RESOURCE_LOCK_NULL) {

	/*
	** The resource is no longer a locknull resource. This will remove
	** the special marker.
	**
	** Note that a locknull resource has already inherited all of the
	** locks from the parent. We do not need to call dav_inherit_locks.
	**
	** NOTE: some lock providers record locks for locknull resources using
	**       a different key than for regular resources. this will shift
	**       the lock information between the two key types.
	*/
	(void)(*lockdb->hooks->remove_locknull_state)(lockdb, resource);

	/*
	** There are resources under this one, which are new. We must
	** propagate the locks down to the new resources.
	*/
	if (depth > 0 &&
	    (err = dav_inherit_locks(r, lockdb, resource, 0)) != NULL) {
	    /* ### add a higher level desc? */
	    return err;
	}
    }
    else if (resource_state == DAV_RESOURCE_NULL) {

	/* ### should pass depth to dav_inherit_locks so that it can
	** ### optimize for the depth==0 case.
	*/

	/* this resource should inherit locks from its parent */
	if ((err = dav_inherit_locks(r, lockdb, resource, 1)) != NULL) {

	    err = dav_push_error(r->pool, err->status, 0,
				 "The resource was created successfully, but "
				 "there was a problem inheriting locks from "
				 "the parent resource.",
				 err);
	    return err;
	}
    }
    /* else the resource already exists and its locks are correct. */

    return NULL;
}
