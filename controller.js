	 	
function Controller()
{
    var self = this; //<- I hate javascript.

    this.noteSelected = function(sender) 
    {
        var note = sender.note;
        model.views.noteView = new NoteView(note);
        model.views.noteViewContainer.innerHTML = '';

        model.views.noteViewContainer.appendChild(model.views.noteViewCloseButton.html);
        model.views.noteViewContainer.appendChild(model.views.noteView.html);
        model.views.noteViewContainer.style.display = 'block';
		model.views.darkness.style.display = 'block';
    };

    this.createNote = function() 
    {
        if(model.playerId > 0)
        {   
            model.views.noteCreateView = new NoteCreateView();
            model.views.createNoteViewContainer.innerHTML = '';
            model.views.createNoteViewContainer.appendChild(model.views.createNoteViewCloseButton.html);
            model.views.createNoteViewContainer.appendChild(model.views.noteCreateView.html);
            model.views.createNoteViewContainer.style.display = 'block';
		    model.views.darkness.style.display = 'block';
		
		    document.getElementById("create_tag_1").checked = true; //this is the default tag, it should be checked (but can't do it in HTML for reasons)

	    }
        else
            this.showLoginView();
    };

    this.showLoginView = function() 
    {
        self.hideJoinView(); // only show one at a time
		model.views.loginView = new LoginView();
        model.views.loginViewContainer.innerHTML = '';
        model.views.loginViewContainer.appendChild(model.views.loginViewCloseButton.html);
        model.views.loginViewContainer.appendChild(model.views.loginView.html);
        model.views.loginViewContainer.style.display = 'block';
		model.views.darkness.style.display = 'block';
    };

    this.showForgotView = function() 
    {
        self.hideLoginView(); // only show one at a time
		model.views.forgotView = new ForgotView();
        model.views.forgotViewContainer.innerHTML = '';
        model.views.forgotViewContainer.appendChild(model.views.forgotViewCloseButton.html);
        model.views.forgotViewContainer.appendChild(model.views.forgotView.html);
        model.views.forgotViewContainer.style.display = 'block';
		model.views.darkness.style.display = 'block';
    };

    this.showJoinView = function() 
    {
        self.hideLoginView(); // only show one at a time
		model.views.joinView = new JoinView();
        model.views.joinViewContainer.innerHTML = '';
        model.views.joinViewContainer.appendChild(model.views.joinViewCloseButton.html);
        model.views.joinViewContainer.appendChild(model.views.joinView.html);
        model.views.joinViewContainer.style.display = 'block';
		model.views.darkness.style.display = 'block';
    };

    this.populateMapNotesFromModel = function(center)
    {	
        for(var i = 0; i < model.mapMarkers.length; i++)
            if(model.mapMarkers[i].marker != null) model.mapMarkers[i].marker.setMap(null);
        model.mapMarkers = [];
        model.views.markerclusterer.clearMarkers();
        var tmpmarker;
        for(var i = 0; i < model.gameNotes.length; i++)
        {
            if(!this.hasAtLeastOneSelectedTag(model.gameNotes[i])) continue;
            if(!this.matchesFilter(model.gameNotes[i], document.getElementById("filterbox").value)) continue;

            tmpmarker = new MapMarker(this.noteSelected, model.gameNotes[i]);
            model.mapMarkers[model.mapMarkers.length] = tmpmarker;
        }

        if(center)
        {
            var bounds = new google.maps.LatLngBounds();
            for(var i = 0; i < model.mapMarkers.length; i++)
                if(model.mapMarkers[i].note.geoloc.Xa != 0 && model.mapMarkers[i].note.geoloc.Ya != 0)
                    bounds.extend(model.mapMarkers[i].note.geoloc);
            setTimeout(function(){ model.views.gmap.fitBounds(bounds); }, 100);
        }
    };

    this.hasAtLeastOneSelectedTag = function(note)
    {
		try{
        	for(var i = 1; i <= 5; i++)
        	{
            	if(document.getElementById("tag"+i).checked)
           		{
                	for(var j = 0; j < note.tags.length; j++)
                	{
                    	if(note.tags[j].tag.toLowerCase() == document.getElementById("tag"+i).value.toLowerCase())
                        return true;
                	}
            	}
       		 }  
			 return false;
			}	catch(err){console.log(err); }; // was getting errors here for a while

    }

    this.populateListNotesFromModel = function()
    {	
        model.views.mainViewLeft.innerHTML = '';

        for(var i = 0; i < model.gameNotes.length; i++)
        {
            if(!this.hasAtLeastOneSelectedTag(model.gameNotes[i])) continue;
            if(!this.matchesFilter(model.gameNotes[i], document.getElementById("filterbox").value)) continue;
            var listNote = new ListNote(this.noteSelected, model.gameNotes[i], i);
            model.views.mainViewLeft.innerHTML += listNote.html;
        }
    };

    this.matchesFilter = function(note, filter)
    {

		filterLC = filter.toLowerCase().trim(); //we'll be comparing everything in lower case, trim off leading & trailing spaces

        if(filterLC == "") return true; 

		// check contributor
        if(note.username.toLowerCase().indexOf(filterLC) != -1) return true;

       //determine if we need to check the media type 
		var mediaTypeSearch = (filterLC == 'audio' || filterLC == 'video'); //text and photos are manadatory 
		
		for (var i = 0; i < note.contents.length; i++){
			if(note.contents[i].type == 'TEXT'){
		
		        // check the title/caption 
				if(note.contents[i].text.toLowerCase().indexOf(filterLC) != -1) return true;

			}
			if (mediaTypeSearch){ //we computed those which don't need to be checked earlier to make this run faster

				//check type
	            if(note.contents[i].type.toLowerCase().indexOf(filterLC) != -1) return true;
			}
		}
		
        
        return false;
    };

	this.getTagIconURL = function (tag){
		var tagIconMediaId = '';
		switch(tag){
			case( model.tags[0].tag): return  model.tags[0].iconURL;   break;
			case( model.tags[1].tag): return  model.tags[1].iconURL;   break;
			case( model.tags[2].tag): return  model.tags[2].iconURL;   break;
			case( model.tags[3].tag): return  model.tags[3].iconURL;   break;
			case( model.tags[4].tag): return  model.tags[4].iconURL;   break;

		default:
			console.log("unexpected tag name");
		}
    
	}


    this.rightSideOfCell = function(text)
    {
        return "<div id='selector_cell_right_id' class='selector_cell_right' style='float:right; vertical-align:middle; padding-top:5px; padding-right:20px';>" + text + "</div>";
    }

    this.hideNoteView = function()
    {
        model.views.noteViewContainer.style.display = 'none';
        model.views.noteViewContainer.innerHTML = '';
		model.views.darkness.style.display = 'none';
        document.removeEventListener('click', controller.hideNoteView, false);
    }

    this.hideCreateNoteView = function()
    {
        model.views.createNoteViewContainer.style.display = 'none';
        model.views.createNoteViewContainer.innerHTML = '';
		model.views.darkness.style.display = 'none';
        document.removeEventListener('click', controller.hideCreateNoteView, false);
    }

    this.hideLoginView = function()
    {
        model.views.loginViewContainer.style.display = 'none';
        model.views.loginViewContainer.innerHTML = '';
		model.views.darkness.style.display = 'none';
        document.removeEventListener('click', controller.hideLoginView, false);
    }
    this.hideForgotView = function()
    {
        model.views.forgotViewContainer.style.display = 'none';
        model.views.forgotViewContainer.innerHTML = '';
		model.views.darkness.style.display = 'none';
        document.removeEventListener('click', controller.hideForgotView, false);
    }

    this.hideJoinView = function()
    {
        model.views.joinViewContainer.style.display = 'none';
        model.views.joinViewContainer.innerHTML = '';
	model.views.darkness.style.display = 'none';
        document.removeEventListener('click', controller.hideJoinView, false);
    }

    this.populateAllFromModel = function()
    {
        this.populateMapNotesFromModel(true);
        this.populateListNotesFromModel();
    }

    this.createNewNote = function()
    {
		// first, reset currentNote to clear out any old data, and give it just lat & lon to start
		model.currentNote = {};
		model.currentNote.lat = model.defaultLat;
		model.currentNote.lon = model.defaultLon;

        var gameId = model.gameId;
        var playerId = model.playerId;		
        callService("notes.createNewNoteStartIncomplete", this.newNoteCreated, "/"+ gameId + "/" + playerId, false);
    }

    this.newNoteCreated = function(returnString)
    {
        var startJson = returnString.indexOf("{");
        var jsonString = returnString.substr(startJson);
        var obj = JSON.parse(jsonString);

        var noteId = obj.data;

        model.currentNote.noteId = noteId;
    }

    this.updateNoteLocation = function(noteId, lat, lon) 
    {
        var gameId = model.gameId;
        var getString = "/"+ gameId + "/" + noteId + "/" + lat + "/" + lon;
        callService("notes.updateLocation", function(){}, getString, false);
    }

    this.addContentToNote = function(noteId, filename, type, text)
    {
        var gameId = model.gameId;
        var playerId = model.playerId;

        if(type == "TEXT")
        {
            var getString = "/"+ noteId + "/" + gameId + "/" + playerId + "/0/" + type + "/" + text;
            callService("notes.addContentToNote", function(){}, getString, false);	
        }
        else
        {
            var getString = "/"+ gameId + "/" + noteId + "/" + playerId + "/" + filename + "/" + type;
			callService("notes.addContentToNoteFromFileName", controller.finalizeNoteUpload, getString, false);	
        }
    }

	this.finalizeNoteUpload = function finalizeNoteUpload(response)
	{

		//There are several server calls which must be done in sequence to push a note to server then to HTML. You could do this in one set of nested callbacks, but it'd be fugly.
		//first, get all the media and content uploaded. 
		//second, set the publicToMap and publicToNotebook flags to true
		//third, set the note as 'compelete'
		//fourth, retrieve the note object back from the server
		//fifth, finally push the new note to HTML

		model.contentsWaitingToUpload -= 1; //one item has uploaded, so we aren't waiting for it anymore. 
		
		//first, get all the media and content uploaded. 
		if(model.contentsWaitingToUpload == 0){
			
			//second, is set the publicToMap and publicToNotebook flags to true
			updateNoteString =  "/" + model.currentNote.noteId + "/" +model.currentNote.text.substring(0,10) + "/1/1" ; //updateNote(noteId, title(displays in Editor Only) ,publicToMap, publicToNotebook
			callService("notes.updateNote", controller.setNoteComplete ,updateNoteString , false); 
			
		}
	}

	this.setNoteComplete = function setNoteComplete(response)
	{
			//third, set the note as 'compelete'
			callService("notes.setNoteComplete", controller.getNewNoteFromServer, "/" + model.currentNote.noteId, false); //setNoteComplete (noteId)
	}

	this.getNewNoteFromServer = function getNewNoteFromServer(response)
	{
			//fourth, retrieve the note object back from the server so you can push it to HTML
			callService("notes.getNoteById", controller.pushNewNote, "/" + model.currentNote.noteId + "/" + model.playerId, false);

	}
	this.pushNewNote = function pushNewNote(note)
	{
		//fifth, finally push the new note to HTML

	    var fullNote = JSON.parse(note).data; //the note will have come in like text
	    if(fullNote.contents.length == 0) console.log("Empty uploaded note");  //if the contents haven't loaded, it won't display
	    model.addNoteFromData(fullNote);  //add it in to the cached model
	    controller.populateAllFromModel();  //re-display the map and left hand images
	}


    this.addCommentToNote = function(noteId, comment, callback)
    {
        callService("notes.addCommentToNote", callback, "/"+model.gameId+"/"+model.playerId+"/"+noteId+"/"+comment, false);
    }

    this.addTagToNote = function(noteId, tag)
    {
        callService("notes.addTagToNote", function(){},"/"+noteId+"/"+model.gameId+"/"+tag, false);
    }

    this.deleteNote = function(noteId)
    {
        callService("notes.deleteNote", function(){}, "/"+noteId, false);
    }

    this.login = function(username, password)
    {
        callService("players.getLoginPlayerObject", this.loginReturned,"/"+username+"/"+password, false);
    }

    this.loginReturned = function(returnString)
    {
        var startJson = returnString.indexOf("{");
        var jsonString = returnString.substr(startJson);
        var obj = JSON.parse(jsonString);

	// first check to see if you have a valid login
	if (obj.data) {

	// updated the display name and player ID to match getLoginPlayerObject data
        var playerId = obj.data.player_id;
		var displayName = obj.data.display_name; //in new user account creation this will be same as username
		if(!obj.display_name){displayName = obj.data.user_name; };//just in case set it to username if display name is blank
 
        model.playerId = playerId;
		model.displayName = displayName;

        if(model.playerId > 0)
    	{
            self.hideLoginView();
	    	model.views.loginButton.style.display = 'none'; // hide login
	    	model.views.uploadButton.style.display = 'inline'; // show upload
			model.views.logoutButton.style.display = 'inline'; // Allow user to log out
			model.views.siftMineButton.style.display = 'inline'; //now they can sift for their own
			$.cookie("sifter", playerId);	//give a cookies so they stay logged in until they close the browser
		}
        else
            alert("Incorrect login. Please try again.");

	}
	else
		alert(obj.returnCodeDescription + ". Please try again");
	
	}

	this.logout = function(){
		$.removeCookie('sifter'); //without the cookie, the user will have to log in again
		model.views.loginButton.style.display = 'inline';
		model.views.uploadButton.style.display = 'none';
		model.views.logoutButton.style.display = 'none';
		model.views.siftMineButton.style.display = 'none';
		model.playerId = 0;	
	}


    this.createAccount = function(email, password,username)
    {
        callService("players.createPlayer", this.createPlayerReturned,"/"+username+"/"+password+"/"+username+"/"+username+"/"+email, false); //added username
    }

    this.createPlayerReturned = function(returnString)
    {
        var obj = JSON.parse(returnString);

        if(obj.returnCode > 0) alert(obj.returnCodeDescription);
        else
        {
            model.playerId = obj.data;
            self.hideLoginView();
            self.hideJoinView();
		    model.views.loginButton.style.display = 'none'; // hide login
		    model.views.uploadButton.style.display = 'inline'; // show upload
	    
        }
    }

    this.resetAndEmailPassword = function(email)
    {
        callService("players.resetAndEmailNewPassword", controller.resetPasswordMessage, "/"+ email, false);
    }

	this.resetPasswordMessage = function(returnString){

		console.log(returnString);

		responseMessage = JSON.parse(returnString);
	
		switch(responseMessage.returnCode)
		{
			case 0: alert("Password reset has been successfuly emailed."); controller.hideForgotView();  break; 
			case 4: alert("No player associated with that email"); break; //should'nt we limit the number of attempts?
			case 5: alert("Error: mail could not be sent."); break; //why does this happen?
			default: console.log("Unexpected resupt from resetPasswordMessage: " +returnString);
		}
	}

	this.like = function(playerId, noteId)
	{
        callService("notes.likeNote", function(){},"/"+playerId+"/"+noteId, false); //add internal like
			
	}

	this.unlike = function(playerId, noteId)
	{
        callService("notes.unlikeNote", function(){},"/"+playerId+"/"+noteId, false); //remove internal like
			
	}

	this.sendEmail = function(playerId, noteId)
	{
		//alert("email" + playerId + noteId);

		note = model.currentNote;
		if (!note.note_id == noteId) //we are making an assumption that the current note is the same as the one desired to email
		{							 //just in case this is in error, record it	
			console.log("Error in email: "+ model.currentNote.note_id + " " + noteId);
		}	

		//initialize the text
		var bodyText = "Check out this note about ";
		var subjectText = "Interesting note on ";
		
		//customize based on the tag
		var tagText = "";
		var formattedTag = note.tagString.toLowerCase().trim();
		switch(formattedTag){
			case("innovation"): tagText = "Innovation " ; break;
			case("must do"): tagText= "a Must Do "; break;
			case("stories of the past"):tagText = "Stories of the Past ";  break;
			case("100 years from now"):tagText = "100 Years From Now ";  break;
			case("madison culture"): tagText = "Madison Culture ";  break;

			default:
				console.log("unexpected tag string on email send " + formattedTag + " " + note.tagString);
				tagText = note.tagString;
		}

		bodyText += tagText;
		subjectText += tagText ;
		
		//customize on if they made it or found it		
		if(playerId == note.owner_id) bodyText += "I made ";
		else bodyText += "I found ";

		bodyText += "on the UW-Madison Campus: " +"\n";		
		subjectText += "from UW-Madison Campus";

		//pull out the note text and photo url
		for (var i = 0; i < note.contents.length; i++)
		{
			if(note.contents[i].type == 'TEXT')
			{
				bodyText += "\"" + note.contents[i].text + "\" \n";
			}
			if(note.contents[i].type == 'PHOTO')
			{
				var bodyImage =  note.contents[i].media.data.url ;
			}

		}

		bodyText += "See the whole note at: www.sifter.org or download the Siftr app \n";
		bodyText += bodyImage;
		
	
		//add one to email sent count
        callService("notes.sharedNoteToEmail", function(){},"/"+playerId+"/"+noteId, false); //add one to email count

		//add all the accumulated strings together	
		emailText = "mailto:?subject="+ escape(subjectText) +"&body=" + escape(bodyText);

		//send the email
		window.open(emailText);		

		//increment the user side HTML
		note.email_shares = parseInt(note.email_shares) + 1;
		document.getElementById("emailButton").innerHTML = note.email_shares + " Emails" ;
		

	}
}
