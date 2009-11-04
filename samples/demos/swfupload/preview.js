SWFUpload.prototype.initSettings = (function (oldInitSettings) {
	return function (userSettings) {
		if (typeof(oldInitSettings) === "function") {
			oldInitSettings.call(this, userSettings);
		}
		
		this.settings.using_preview = true;
	};
})(SWFUpload.prototype.initSettings);
SWFUpload.prototype.getFlashVars = (function (oldGetFlashVars) {
	return function (userSettings) {
		return oldGetFlashVars.call(this) +
			"&amp;usingPreview=" + encodeURIComponent(this.settings.using_preview);
	};
})(SWFUpload.prototype.getFlashVars);


/* ******************* */
/* Constructor & Init  */
/* ******************* */


if (SWFUpload.Preview == undefined) {
	SWFUpload.Preview = function (settings) {
		this.init(settings);
	};
}

SWFUpload.Preview.prototype.init = function (userSettings) {
	try {
		this.settings = {};
		this.eventQueue = [];
		this.movieName = "Preview_" + SWFUpload.Preview.movieCount++;
		this.movieElement = null;
		this.swfUpload = null;


		// Setup global control tracking
		SWFUpload.Preview.instances[this.movieName] = this;

		// Load the settings.  Load the Flash movie.
		this.initSettings(userSettings);
		this.loadFlash();
		this.displayDebugInfo();
	} catch (ex) {
		delete SWFUpload.Preview.instances[this.movieName];
		throw ex;
	}
};

/* *************** */
/* Static Members  */
/* *************** */
SWFUpload.Preview.instances = {};
SWFUpload.Preview.movieCount = 0;
SWFUpload.Preview.version = "0.1";

/* ******************** */
/* Instance Members  */
/* ******************** */

// Private: initSettings ensures that all the
// settings are set, getting a default value if one was not assigned.
SWFUpload.Preview.prototype.initSettings = function (userSettings) {
	this.ensureDefault = function (settingName, defaultValue) {
		var setting = userSettings[settingName];
		if (setting != undefined) {
			this.settings[settingName] = setting;
		} else {
			this.settings[settingName] = defaultValue;
		}
	};
	
	this.ensureDefault("flash_url", "preview.swf");
	this.ensureDefault("preview_placeholder_id", "");
	this.ensureDefault("preview_placeholder", null);
	this.ensureDefault("preview_window_mode", SWFUpload.WINDOW_MODE.OPAQUE);
	
	this.ensureDefault("resize_to_fit", true);
	this.ensureDefault("width", 100);
	this.ensureDefault("height", 100);

	// Debug Settings
	this.ensureDefault("debug", false);

	// Event handlers
	this.ensureDefault("preview_loaded_handler", null);
	this.ensureDefault("preview_complete_handler", null);
	this.ensureDefault("debug_handler", this.debugMessage);

	delete this.ensureDefault;
};

// Private: loadFlash replaces the preview_placeholder element with the flash movie.
SWFUpload.Preview.prototype.loadFlash = function () {
	var targetElement, tempParent;

	// Make sure an element with the ID we are going to use doesn't already exist
	if (document.getElementById(this.movieName) !== null) {
		throw "ID " + this.movieName + " is already in use. The Flash Object could not be added";
	}

	// Get the element where we will be placing the flash movie
	targetElement = document.getElementById(this.settings.preview_placeholder_id) || this.settings.preview_placeholder;

	if (targetElement == undefined) {
		throw "Could not find the placeholder element: " + this.settings.preview_placeholder_id;
	}

	var wrapperType = (targetElement.currentStyle && targetElement.currentStyle["display"] || window.getComputedStyle && document.defaultView.getComputedStyle(targetElement, null).getPropertyValue("display")) !== "block" ? "span" : "div";
	
	// Append the container and load the flash
	tempParent = document.createElement(wrapperType);
	tempParent.innerHTML = this.getFlashHTML();	// Using innerHTML is non-standard but the only sensible way to dynamically add Flash in IE (and maybe other browsers)
	targetElement.parentNode.replaceChild(tempParent.firstChild, targetElement);

	// Fix IE Flash/Form bug
	if (window[this.movieName] == undefined) {
		window[this.movieName] = this.getMovieElement();
	}
	
};

// Private: getFlashHTML generates the object tag needed to embed the flash in to the document
SWFUpload.Preview.prototype.getFlashHTML = function () {
	// Flash Satay object syntax: http://www.alistapart.com/articles/flashsatay
	return ['<object id="', this.movieName, '" type="application/x-shockwave-flash" data="', this.settings.flash_url, '" width="', this.settings.width, '" height="', this.settings.height, '" class="swfupload">',
				'<param name="wmode" value="', this.settings.preview_window_mode, '" />',
				'<param name="movie" value="', this.settings.flash_url, '" />',
				'<param name="quality" value="high" />',
				'<param name="menu" value="false" />',
				'<param name="allowScriptAccess" value="always" />',
				'<param name="flashvars" value="' + this.getFlashVars() + '" />',
				'</object>'].join("");
};

// Private: getFlashVars builds the parameter string that will be passed
// to flash in the flashvars param.
SWFUpload.Preview.prototype.getFlashVars = function () {
	// Build the parameter string
	return ["movieName=", encodeURIComponent(this.movieName),
			"&amp;debug=", encodeURIComponent(this.settings.debug)
		].join("");
};

// Public: getMovieElement retrieves the DOM reference to the Flash element added by SWFUpload
// The element is cached after the first lookup
SWFUpload.Preview.prototype.getMovieElement = function () {
	if (this.movieElement == undefined) {
		this.movieElement = document.getElementById(this.movieName);
	}

	if (this.movieElement === null) {
		throw "Could not find Flash element";
	}
	
	return this.movieElement;
};

// Public: Used to remove a Preview instance from the page. This method strives to remove
// all references to the SWF, and other objects so memory is properly freed.
// Returns true if everything was destroyed. Returns a false if a failure occurs leaving SWFUpload in an inconsistant state.
// Credits: Major improvements provided by steffen
SWFUpload.Preview.prototype.destroy = function () {
	try {
		var movieElement = this.cleanUp();

		// Remove the SWFUpload DOM nodes
		if (movieElement) {
			// Remove the Movie Element from the page
			try {
				movieElement.parentNode.removeChild(movieElement);
			} catch (ex) {}
		}

		// Remove IE form fix reference
		window[this.movieName] = null;

		// Destroy other references
		SWFUpload.Preview.instances[this.movieName] = null;
		delete SWFUpload.Preview.instances[this.movieName];

		this.movieElement = null;
		this.settings = null;
		this.customSettings = null;
		this.eventQueue = null;
		this.movieName = null;
		this.swfUpload = null;
		
		
		return true;
	} catch (ex2) {
		return false;
	}
};


// Public: displayDebugInfo prints out settings and configuration
// information about this SWFUpload instance.
// This function (and any references to it) can be deleted when placing
// SWFUpload in production.
SWFUpload.Preview.prototype.displayDebugInfo = function () {
	this.debug(
		[
			"---Preview Instance Info---\n",
			"Version: ", SWFUpload.Preview.version, "\n",
			"Movie Name: ", this.movieName, "\n",
			"Settings:\n",
			"\t", "flash_url:                ", this.settings.flash_url, "\n",
			"\t", "debug:                    ", this.settings.debug.toString(), "\n",
			"\t", "preview_placeholder_id:   ", this.settings.preview_placeholder_id.toString(), "\n",
			"\t", "preview_placeholder:      ", (this.settings.preview_placeholder ? "Set" : "Not Set"), "\n",

			"Event Handlers:\n",
			"\t", "preview_loaded_handler assigned:  ", (typeof this.settings.preview_loaded_handler === "function").toString(), "\n",
			"\t", "preview_complete_handler assigned:   ", (typeof this.settings.preview_complete_handler === "function").toString(), "\n",
			"\t", "debug_handler assigned:             ", (typeof this.settings.debug_handler === "function").toString(), "\n"
		].join("")
	);
};

// Private: callFlash handles function calls made to the Flash element.
// Calls are made with a setTimeout for some functions to work around
// bugs in the ExternalInterface library.
SWFUpload.Preview.prototype.callFlash = function (functionName, argumentArray) {
	argumentArray = argumentArray || [];
	
	var movieElement = this.getMovieElement();
	var returnValue, returnString;

	// Flash's method if calling ExternalInterface methods (code adapted from MooTools).
	try {
		returnString = movieElement.CallFunction('<invoke name="' + functionName + '" returntype="javascript">' + __flash__argumentsToXML(argumentArray, 0) + '</invoke>');
		returnValue = eval(returnString);
	} catch (ex) {
		throw "Call to " + functionName + " failed";
	}
	
	// Unescape file post param values
	if (returnValue != undefined && typeof returnValue.post === "object") {
		returnValue = this.unescapeFilePostParams(returnValue);
	}

	return returnValue;
};

/* *****************************
	-- Flash control methods --
	Your UI should use these
	to operate SWFUpload
   ***************************** */

// Public: startUpload starts uploading the first file in the queue unless
// the optional parameter 'fileID' specifies the ID 
SWFUpload.Preview.prototype.getPreview = function (swfUploadMovieName, file_id, width, height) {
	this.debug("Called getPreview: " + swfUploadMovieName + " " + file_id);
	this.swfUpload = SWFUpload.instances[swfUploadMovieName];
	this.setPreviewDimensions(width, height);
	this.callFlash("LoadImage", [swfUploadMovieName, file_id, width, height]);
};

// Public: setDebugEnabled changes the debug_enabled setting
SWFUpload.Preview.prototype.setDebugEnabled = function (debugEnabled) {
	this.settings.debug_enabled = debugEnabled;
	this.callFlash("SetDebugEnabled", [debugEnabled]);
};

// Public: setButtonDimensions resizes the Flash Movie
SWFUpload.Preview.prototype.setPreviewDimensions = function (width, height) {
	this.debug("Resizing preview to " + width + " by " + height);
	var movie = this.getMovieElement();
	if (movie != undefined && this.settings.resize_to_fit) {
		movie.style.width = width + "px";
		movie.style.height = height + "px";
	}
	
};


/* *******************************
	Flash Event Interfaces
	These functions are used by Flash to trigger the various
	events.
	
	All these functions a Private.
	
	Because the ExternalInterface library is buggy the event calls
	are added to a queue and the queue then executed by a setTimeout.
	This ensures that events are executed in a determinate order and that
	the ExternalInterface bugs are avoided.
******************************* */

SWFUpload.Preview.prototype.queueEvent = function (handlerName, argumentArray) {
	// Warning: Don't call this.debug inside here or you'll create an infinite loop
	
	if (argumentArray == undefined) {
		argumentArray = [];
	} else if (!(argumentArray instanceof Array)) {
		argumentArray = [argumentArray];
	}
	
	var self = this;
	if (typeof this.settings[handlerName] === "function") {
		// Queue the event
		this.eventQueue.push(function () {
			this.settings[handlerName].apply(this, argumentArray);
		});
		
		// Execute the next queued event
		setTimeout(function () {
			self.executeNextEvent();
		}, 0);
		
	} else if (this.settings[handlerName] !== null) {
		throw "Event handler " + handlerName + " is unknown or is not a function";
	}
};

// Private: Causes the next event in the queue to be executed.  Since events are queued using a setTimeout
// we must queue them in order to garentee that they are executed in order.
SWFUpload.Preview.prototype.executeNextEvent = function () {
	// Warning: Don't call this.debug inside here or you'll create an infinite loop

	var  f = this.eventQueue ? this.eventQueue.shift() : null;
	if (typeof(f) === "function") {
		f.apply(this);
	}
};

// Private: This event is called by Flash when it has finished loading. Don't modify this.
// Use the swfupload_loaded_handler event setting to execute custom code when SWFUpload has loaded.
SWFUpload.Preview.prototype.flashReady = function () {
	// Check that the movie element is loaded correctly with its ExternalInterface methods defined
	var movieElement = this.getMovieElement();

	if (!movieElement) {
		this.debug("Flash called back ready but the flash movie can't be found.");
		return;
	}

	this.cleanUp();
	
	this.queueEvent("preview_loaded_handler");
};

// Private: removes Flash added fuctions to the DOM node to prevent memory leaks in IE.
// This function is called by Flash each time the ExternalInterface functions are created.
SWFUpload.Preview.prototype.cleanUp = function () {
	var movieElement = this.getMovieElement();
	
	// Pro-actively unhook all the Flash functions
	try {
		if (movieElement && typeof(movieElement.CallFunction) === "unknown") { // We only want to do this in IE
			this.debug("Removing Flash functions hooks (this should only run in IE and should prevent memory leaks)");
			for (var key in movieElement) {
				try {
					if (typeof(movieElement[key]) === "function") {
						movieElement[key] = null;
					}
				} catch (ex) {
				}
			}
		}
	} catch (ex1) {
	
	}

	// Fix Flashes own cleanup code so if the SWF Movie was removed from the page
	// it doesn't display errors.
	window["__flash__removeCallback"] = function (instance, name) {
		try {
			if (instance) {
				instance[name] = null;
			}
		} catch (flashEx) {
		
		}
	};
	
	return movieElement;
};


SWFUpload.Preview.prototype.previewComplete = function () {
	this.queueEvent("preview_complete_handler");
};

/* Called by SWFUpload JavaScript and Flash functions when debug is enabled. By default it writes messages to the
   internal debug console.  You can override this event and have messages written where you want. */
SWFUpload.Preview.prototype.debug = function (message) {
	this.queueEvent("debug_handler", message);
};


// Private: debugMessage is the default debug_handler.  If you want to print debug messages
// call the debug() function.  When overriding the function your own function should
// check to see if the debug setting is true before outputting debug information.
SWFUpload.Preview.prototype.debugMessage = function (message) {
	if (this.settings.debug) {
		var exceptionMessage, exceptionValues = [];

		// Check for an exception object and print it nicely
		if (typeof message === "object" && typeof message.name === "string" && typeof message.message === "string") {
			for (var key in message) {
				if (message.hasOwnProperty(key)) {
					exceptionValues.push(key + ": " + message[key]);
				}
			}
			exceptionMessage = exceptionValues.join("\n") || "";
			exceptionValues = exceptionMessage.split("\n");
			exceptionMessage = "EXCEPTION: " + exceptionValues.join("\nEXCEPTION: ");
			SWFUpload.Console.writeLine(exceptionMessage);
		} else {
			SWFUpload.Console.writeLine(message);
		}
	}
};
