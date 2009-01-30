if( !SkillsPlugin ) var SkillsPlugin = {};

SkillsPlugin.main = function() {
    
    return {
        
        init: function() {

        },

        twist: function( elTwistyLink ) {
            var yuiEl = new YAHOO.util.Element();
            
            var twistyId = elTwistyLink.id.replace( /_.*$/, '');
            
            var elsToTwist = yuiEl.getElementsByClassName( twistyId + '_twist' );
            
            var elTwistyImgCont;
            var elTwistyImg;
            if( elTwistyImgCont = document.getElementById( twistyId + '_twistyImage' ) ){
                elTwistyImg = document.getElementById( twistyId + '_twistyImage' ).childNodes[1];
            }
            
            // are we open or close?
            var elTwistyLink = new YAHOO.util.Element(elTwistyLink);
            if( elTwistyLink.hasClass( 'twistyopen' ) ){
                elTwistyLink.replaceClass( 'twistyopen', 'twistyclosed' );
                for( var i in elsToTwist ){
                    this.closeTwist( elsToTwist[i], elTwistyImg );
                }
            }
            else if( elTwistyLink.hasClass( 'twistyclosed' ) ){
                elTwistyLink.replaceClass( 'twistyclosed', 'twistyopen' );
                var i;
                for( i in elsToTwist ){
                    this.openTwist( elsToTwist[i], elTwistyImg );
                }
            } else {
                elTwistyLink.addClass( 'twistyclosed' );
                var i;
                for( i in elsToTwist ){
                    this.closeTwist( elsToTwist[i], elTwistyImg );
                }
            }
        },
        
        openTwist: function( twistEl, imageEl ) {
            try {
                twistEl.style.display = '';
            } catch(e) {
                twistEl.style.display = 'block';
            }
            if( imageEl ){
                imageEl.src = SkillsPlugin.vars.twistyCloseImgSrc;
            }
        },
        
        closeTwist: function( twistEl, imageEl ) {
            twistEl.style.display = 'none';
            if( imageEl ){
                imageEl.src = SkillsPlugin.vars.twistyOpenImgSrc;
            }
        }
    }
}();
//SkillsPlugin.main.init();

SkillsPlugin.viewUserSkills = function () {
    
    return {
        
        init: function(){
            YAHOO.util.Event.onDOMReady(this.initTwisty, this, true);
        },
        
        initTwisty: function(){
            // sets up the twisty
            var yuiEl = new YAHOO.util.Element();
            
            if ( SkillsPlugin.vars.twistyState == 'off' ){
                return;
            }
            
            var arEls = yuiEl.getElementsByClassName('SkillsPlugin-twisty-link', 'span');
            
            var fnTwistCallback = function(){
                SkillsPlugin.main.twist( this );
            };
            
            // add event to an array of elements
            YAHOO.util.Event.addListener(
                arEls,
                "click",
                fnTwistCallback
                );
            
            // loop over all twisty links
            for ( var i = arEls.length - 1; i >= 0; --i ){
                var twistyId = arEls[i].id.replace( /_.*$/, '');
                
                var elLink = new YAHOO.util.Element( twistyId + '_twistyLink' );
                elLink.addClass('active');
                var elImg = new YAHOO.util.Element( twistyId + '_twistyImage' );
                elImg.addClass('active');
                
                // set initial state
                if( SkillsPlugin.vars.twistyState == 'closed' ){
                    SkillsPlugin.main.twist( arEls[i] );
                }
            }
        }
    }
}();
if( SkillsPlugin.vars.viewUserSkills ){ 
    SkillsPlugin.viewUserSkills.init();
}

SkillsPlugin.addEditSkills = function () {
    
    var
        _idSelCategory = "addedit-category-select",
        _idSelSkill = "addedit-skill-select",
        _idRating = "addedit-skill-rating",
        _idComment = "addedit-skill-comment",
        _idClearComment = "addedit-skill-comment-clear",
        _idSubmit = "addedit-skill-submit",
        _idForm = "addedit-skill-form",
        _idMessageContainer = "addedit-skills-message-container",
        _idMessage = "addedit-skills-message",
        
        _locked = 0;
        
    // common function for all connection failures
    var _connectionFailure = function(o){
        alert("Connection failure '" + o.statusText + "'. Please notify your administrator, giving the reason for this failure and as much information about the problem as possible.");
    }
    
    // gets the categories from the server
    var _getCategories = function( fnCallback ){
        var url = SkillsPlugin.vars.restUrl + "/SkillsPlugin/getCategories";
        
        var obCallbacks = {
			success: function(o){
                _unlock();
                _disableRatingSelect();
                _disableCommentInput();
                _resetSkillDetails();
                
                var arCats = o.responseText.split( "|" ); // JSON?
                arCats.sort();
                fnCallback( arCats );
			},
			failure: function(o){_connectionFailure(o)}
		}
        _lock();
		var request = YAHOO.util.Connect.asyncRequest('GET', url, obCallbacks); 
    }
    
    // gets the skills from the server
    var _getSkills = function( category, fnCallback ){
        var url = SkillsPlugin.vars.restUrl + "/SkillsPlugin/getSkills";
        url += "?category=" + encodeURIComponent(category);
        
        var obCallbacks = {
			success: function(o){
                _unlock();
                _disableRatingSelect();
                _disableCommentInput();
                _resetSkillDetails();
                
                // TODO: need to check there are some skills!!
                var arSkills = o.responseText.split( "|" ); // JSON?
                arSkills.sort();
                fnCallback( arSkills );
			},
			failure: function(o){_connectionFailure(o)}
		}
        _lock();
		var request = YAHOO.util.Connect.asyncRequest('GET', url, obCallbacks);
    }
    
    // gets the rating and the comment for a particular skill from the server
    var _getSkillDetails = function( category, skill, fnCallback ){
        var url = SkillsPlugin.vars.restUrl + "/SkillsPlugin/getSkillDetails";
        url += "?category=" + encodeURIComponent(category);
        url += "&skill=" + encodeURIComponent(skill);
        
        var obCallbacks = {
			success: function(o){
                _unlock();
                if( o.responseText == '' ){
                    // skill not found (new skill)
                    // set 'None' on skill rating
                    for( var i=0; i < document[_idForm][_idRating].length; i++ ){
                        if( document[_idForm][_idRating][i].value == 0 ){
                            document[_idForm][_idRating][i].checked = true;
                        }
                    }
                } else {
                    obSkillDetails = YAHOO.lang.JSON.parse(o.responseText);
                    fnCallback( obSkillDetails.rating, obSkillDetails.comment );
                }
			},
			failure: function(o){_connectionFailure(o)}
		}
        _lock();
		var request = YAHOO.util.Connect.asyncRequest('GET', url, obCallbacks);
    }
    
    // hides the 'clear comment' button
    var _hideClearComment = function(){
        var el = document.getElementById(_idClearComment);
        el.style.display='none';
    }
    
    // shows the 'clear comment' button
    var _showClearComment = function(){
        var el = document.getElementById(_idClearComment);
        el.style.display='';
    }
    
    // clears the rating and the comment
    var _resetSkillDetails = function(){
        // reset details
        for( var i=0; i < document[_idForm][_idRating].length; i++ ){
            if( document[_idForm][_idRating][i].checked == true ){
                document[_idForm][_idRating][i].checked = false;
            }
        }
        var elComment = document.getElementById(_idComment);
        elComment.value = '';
        _hideClearComment();
    }
    
    // clears the skill drop down menu
    var _resetSkillSelect = function(){
        var elSkillSelect = document.getElementById(_idSelSkill);
        elSkillSelect.options.length = 0;
    }
    
    // resets the entire form to its initial state
    var _resetForm = function(){
        _resetSkillSelect();
        _resetSkillDetails();
        SkillsPlugin.addEditSkills.populateCategories();
    }
    
    // disable the rating option boxes
    var _disableRatingSelect = function(){
        for( var i=0; i < document[_idForm][_idRating].length; i++ ){
            document[_idForm][_idRating][i].disabled = true;
        }
    }
    
    // enables the rating options
    var _enableRatingSelect = function(){
        for( var i=0; i < document[_idForm][_idRating].length; i++ ){
            document[_idForm][_idRating][i].disabled = false;
        }
    }
    
    // disables the comment text box
    var _disableCommentInput = function(){
        var elComment = document.getElementById(_idComment);
        elComment.disabled = true;
    }
    
    // enables the comment text box
    var _enableCommentInput = function(){
        var elComment = document.getElementById(_idComment);
        elComment.disabled = false;
    }
    
    // lock form when AJAX in progress
    var _lock = function(){
        if( _locked == 1 ){
            return;
        }
        _locked = 1;
        
        var elSelCat = document.getElementById(_idSelCategory);
        elSelCat.disabled = true;
        var elSelSkill = document.getElementById(_idSelSkill);
        elSelSkill.disabled = true;
        _disableRatingSelect();
        _disableCommentInput();
        var elSubmit = document.getElementById(_idSubmit);
        elSubmit.disabled = true;
    }
    
    // unlocks the form
    var _unlock = function(){
        if( _locked == 0 ){
            return;
        }
        _locked = 0;
        
        var elSelCat = document.getElementById(_idSelCategory);
        elSelCat.disabled = false;
        var elSelSkill = document.getElementById(_idSelSkill);
        elSelSkill.disabled = false;
        _enableRatingSelect();
        _enableCommentInput();
        var elSubmit = document.getElementById(_idSubmit);
        elSubmit.disabled = false;
    }
    
    // displays a notification recieved from the server
    var _displayMessage = function(message){
		
        var elMessage = document.getElementById(_idMessage);
		elMessage.innerHTML = message;
		
		_showMessage( elMessage );
	}
	
    // shows the message
	var _showMessage = function(){
        var elMessageContainer = document.getElementById(_idMessageContainer);
        elMessageContainer.style.display = '';
		// message is shown for 10 seconds
		var obAnim = new YAHOO.util.Anim(
			elMessageContainer,
			{
				opacity: {to: 0, from:1}
			}, 
			10
		);
		obAnim.animate();
	}
    
    return {
        
        init: function(){
            // register events
            YAHOO.util.Event.onAvailable(_idSelCategory, this.populateCategories, this, true);
            
            YAHOO.util.Event.addListener(_idSelCategory, "change", this.populateSkills, this, true);
            YAHOO.util.Event.addListener(_idSelSkill, "change", this.populateSkillDetails, this, true);
            
            YAHOO.util.Event.addListener(_idComment, "keyup", this.commentKeyPress, this, true);
            
            YAHOO.util.Event.addListener(_idClearComment, "click", this.clearComment, this, true);
            YAHOO.util.Event.addListener(_idSubmit, "click", this.submit, this, true);
        },
        
        // populates the category select menu
        populateCategories: function(){
            var elCatSelect = document.getElementById(_idSelCategory);
            elCatSelect.options.length = 0;
            
            if( SkillsPlugin.vars.loggedIn == 0 ){
                elCatSelect.options[0] = new Option("Please log in...", "0", true);
                _lock();
                return;
            }
            elCatSelect.options[0] = new Option("Loading...", "0", true);
            
            var fnCallback = function( arCats ){
                elCatSelect.options[0] = new Option("Select a category...", "0", true);
                var count = 1;
                for( var i in arCats ){
                    elCatSelect.options[count] = new Option(arCats[i], arCats[i]);
                    count ++;
                }
            }
            
            _getCategories( fnCallback );
            elCatSelect.selectedIndex = 0;
            var elSkillSelect = document.getElementById(_idSelSkill);
            elSkillSelect.options[0] = new Option("Select a category above...", "0", true);
        },
        
        // populates the skill select menu
        populateSkills: function(){
            var elSkillSelect = document.getElementById(_idSelSkill);
            
            // get selected category (could be stored in global variable)?
            var elCatSelect = document.getElementById(_idSelCategory);
            var catSelIndex = elCatSelect.selectedIndex;
            var cat = elCatSelect.options[catSelIndex].value;
            
            // ensure any previous skills are removed from options
            elSkillSelect.options.length = 0;
            
            if( cat == 0 ){
                elSkillSelect.options[0] = new Option("Select a category above...", "0", true);
                return;
            }
            
            elSkillSelect.options[0] = new Option("Loading...", "0", true);
            
            var fnCallback = function( arSkills ){
                elSkillSelect.options[0] = new Option("Select a skill...", "0", true);
                var count = 1;
                for( var i in arSkills ){
                    if(arSkills[i] == ''){
                        continue;
                    }
                    elSkillSelect.options[count] = new Option(arSkills[i], arSkills[i]);
                    count ++;
                }
            }
            
            _getSkills( cat, fnCallback );
        },
        
        // populates the rating and the comment for a skill
        populateSkillDetails: function(){
            _resetSkillDetails();
            
            // get selected category and skill
            var elCatSelect = document.getElementById(_idSelCategory);
            var catSelIndex = elCatSelect.selectedIndex;
            var cat = elCatSelect.options[catSelIndex].value;
            
            var elSkillSelect = document.getElementById(_idSelSkill);
            var skillSelIndex = elSkillSelect.selectedIndex;
            var skill = elSkillSelect.options[skillSelIndex].value;
            
            var fnCallback = function( ratingValue, comment ){
                if( ratingValue ){
                    // select the rating radio button
                    for( var i=0; i < document[_idForm][_idRating].length; i++ ){
                        if( document[_idForm][_idRating][i].value == ratingValue ){
                            document[_idForm][_idRating][i].checked = true;
                            break;
                        }
                    }
                }
                
                if( comment ){
                    // set comment
                    var elComment = document.getElementById(_idComment);
                    elComment.value = comment;
                    _showClearComment();
                }
            }
            
            _getSkillDetails( cat, skill, fnCallback );
        },
        
        // submits the form
        submit: function(){
            var url = SkillsPlugin.vars.restUrl + "/SkillsPlugin/addEditSkill";
            
            var obCallbacks = {
                success: function(o){
                    _unlock();
                    _displayMessage(o.responseText);
                    _resetForm();
                },
                failure: function(o){_connectionFailure(o)}
            }
            
            YAHOO.util.Connect.setForm(_idForm);
            _lock();
            YAHOO.util.Connect.asyncRequest('POST', url, obCallbacks);
        },
        
        // clears the comment text field
        clearComment: function(){
            var elComment = document.getElementById(_idComment);
            elComment.value = '';
            _hideClearComment();
        },
        
        // react to a key press in the comment text box
        commentKeyPress: function(e){
            var el = YAHOO.util.Event.getTarget(e);
            if( el.value.length == 0 ){
                _hideClearComment();
            } else {
                _showClearComment();
            }
        }
    };
    
}();
if( SkillsPlugin.vars.addEditSkills ){
    SkillsPlugin.addEditSkills.init();
}

SkillsPlugin.searchSkills = function () {
    
    var
        _idSelCategory = "search-category-select",
        _idSelSkill = "search-skill-select",
        _idSubmit = "search-skill-submit",
        _idForm = "search-skill-form",
        _idResults = "search-skill-results"
        
        _locked = 0;
        
    // common function for all connection failures
    // SMELL: could be in main
    var _connectionFailure = function(o){
        alert("Connection failure '" + o.statusText + "'. Please notify your administrator, giving the reason for this failure and as much information about the problem as possible.");
    }
    
    // gets the categories from the server
    var _getCategories = function( fnCallback ){
        var url = SkillsPlugin.vars.restUrl + "/SkillsPlugin/getCategories";
        
        var obCallbacks = {
			success: function(o){
                _unlock();
                
                var arCats = o.responseText.split( "|" ); // JSON?
                arCats.sort();
                fnCallback( arCats );
			},
			failure: function(o){_connectionFailure(o)}
		}
        _lock();
		var request = YAHOO.util.Connect.asyncRequest('GET', url, obCallbacks); 
    }
    
    // gets the skills from the server
    var _getSkills = function( category, fnCallback ){
        var url = SkillsPlugin.vars.restUrl + "/SkillsPlugin/getSkills";
        url += "?category=" + encodeURIComponent(category);
        
        var obCallbacks = {
			success: function(o){
                _unlock();
                //_disableRatingSelect();
                //_disableCommentInput();
                
                // TODO: need to check there are some skills!!
                var arSkills = o.responseText.split( "|" ); // JSON?
                arSkills.sort();
                fnCallback( arSkills );
			},
			failure: function(o){_connectionFailure(o)}
		}
        _lock();
		var request = YAHOO.util.Connect.asyncRequest('GET', url, obCallbacks);
    }
    
    
    // clears the skill drop down menu
    var _resetSkillSelect = function(){
        var elSkillSelect = document.getElementById(_idSelSkill);
        elSkillSelect.options.length = 0;
    }
    
    // resets the entire form to its initial state
    var _resetForm = function(){
        _resetSkillSelect();
        SkillsPlugin.searchSkills.populateCategories();
    }
    
    // lock form when AJAX in progress
    var _lock = function(){
        if( _locked == 1 ){
            return;
        }
        _locked = 1;
        
        var elSelCat = document.getElementById(_idSelCategory);
        elSelCat.disabled = true;
        var elSelSkill = document.getElementById(_idSelSkill);
        elSelSkill.disabled = true;
        var elSubmit = document.getElementById(_idSubmit);
        elSubmit.disabled = true;
    }
    
    // unlocks the form
    var _unlock = function(){
        if( _locked == 0 ){
            return;
        }
        _locked = 0;
        
        var elSelCat = document.getElementById(_idSelCategory);
        elSelCat.disabled = false;
        var elSelSkill = document.getElementById(_idSelSkill);
        elSelSkill.disabled = false;
        var elSubmit = document.getElementById(_idSubmit);
        elSubmit.disabled = false;
    }
    
    var _populateResults = function( results ){
        var elResults = document.getElementById(_idResults);
        elResults.innerHTML = results;
    }
    
    return {
        
        init: function(){
            // register events
            YAHOO.util.Event.onAvailable(_idSelCategory, this.populateCategories, this, true);
            
            YAHOO.util.Event.addListener(_idSelCategory, "change", this.populateSkills, this, true);
            
            YAHOO.util.Event.addListener(_idSubmit, "click", this.submit, this, true);
        },
        
        // populates the category select menu
        populateCategories: function(){
            var elCatSelect = document.getElementById(_idSelCategory);
            elCatSelect.options.length = 0;
            
            if( SkillsPlugin.vars.loggedIn == 0 ){
                elCatSelect.options[0] = new Option("Please log in...", "0", true);
                _lock();
                return;
            }
            elCatSelect.options[0] = new Option("Loading...", "0", true);
            
            var fnCallback = function( arCats ){
                elCatSelect.options[0] = new Option("Select a category...", "0", true);
                var count = 1;
                for( var i in arCats ){
                    elCatSelect.options[count] = new Option(arCats[i], arCats[i]);
                    count ++;
                }
            }
            
            _getCategories( fnCallback );
            elCatSelect.selectedIndex = 0;
            var elSkillSelect = document.getElementById(_idSelSkill);
            elSkillSelect.options[0] = new Option("Select a category...", "0", true);
        },
        
        // populates the skill select menu
        populateSkills: function(){
            var elSkillSelect = document.getElementById(_idSelSkill);
            
            // get selected category (could be stored in global variable)?
            var elCatSelect = document.getElementById(_idSelCategory);
            var catSelIndex = elCatSelect.selectedIndex;
            var cat = elCatSelect.options[catSelIndex].value;
            
            // ensure any previous skills are removed from options
            elSkillSelect.options.length = 0;
            
            if( cat == 0 ){
                elSkillSelect.options[0] = new Option("Select a category...", "0", true);
                return;
            }
            
            elSkillSelect.options[0] = new Option("Loading...", "0", true);
            
            var fnCallback = function( arSkills ){
                elSkillSelect.options[0] = new Option("Select a skill...", "0", true);
                var count = 1;
                for( var i in arSkills ){
                    if(arSkills[i] == ''){
                        continue;
                    }
                    elSkillSelect.options[count] = new Option(arSkills[i], arSkills[i]);
                    count ++;
                }
            }
            
            _getSkills( cat, fnCallback );
        },
        
        // submits the form
        submit: function(){
            var url = SkillsPlugin.vars.restUrl + '/SkillsPlugin/search';
            
            var obCallbacks = {
                success: function(o){
                    _unlock();
                    _populateResults(o.responseText);
                },
                failure: function(o){_connectionFailure(o)}
            }
            
            YAHOO.util.Connect.setForm(_idForm);
            _lock();
            YAHOO.util.Connect.asyncRequest('POST', url, obCallbacks);
        }
    };
    
}();
if( SkillsPlugin.vars.searchSkills ){
    SkillsPlugin.searchSkills.init();
}

SkillsPlugin.browseSkills = function () {
    
    return {
        
        init: function(){
            YAHOO.util.Event.onDOMReady(this.initTwisty, this, true);
        },
        
        initTwisty: function(){
            // sets up the twisty
            var yuiEl = new YAHOO.util.Element();
            
            if ( SkillsPlugin.vars.twistyState == 'off' ){
                return;
            }
            
            var arEls = yuiEl.getElementsByClassName('SkillsPlugin-twisty-link', 'span');
            
            var fnTwistCallback = function(){
                SkillsPlugin.main.twist( this );
            };
            
            // add event to an array of elements
            YAHOO.util.Event.addListener(
                arEls,
                "click",
                fnTwistCallback
                );
            
            // loop over all twisty links
            for ( var i = arEls.length - 1; i >= 0; --i ){
                var twistyId = arEls[i].id.replace( /_.*$/, '');
                
                
                var elLink = new YAHOO.util.Element( twistyId + '_twistyLink' );
                elLink.addClass('active');
                var elImg = new YAHOO.util.Element( twistyId + '_twistyImage' );
                elImg.addClass('active');
                
                // set initial state
                if( SkillsPlugin.vars.twistyState == 'closed' ){
                    SkillsPlugin.main.twist( arEls[i] );
                }
                //alert(twistyId);
            }
        }
    }
}();
if( SkillsPlugin.vars.browseSkills ){ 
    SkillsPlugin.browseSkills.init();
}