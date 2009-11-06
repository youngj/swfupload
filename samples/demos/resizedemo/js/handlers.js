var swfu;
window.onload = function () {
	swfu = new SWFUpload({
		// Backend Settings
		upload_url: "upload.php",

		// File Upload Settings
		file_size_limit : "10 MB",	// 2MB
		file_types : "*.jpg;*.png;*.gif",
		file_types_description : "JPG Images; PNG Images; GIF Images",
		file_upload_limit : 0,

		// Event Handler Settings - these functions as defined in Handlers.js
		//  The handlers are not part of SWFUpload but are part of my website and control how
		//  my website reacts to the SWFUpload events.
		file_queued_handler : fileQueued,
		file_queue_error_handler : fileQueueError,

		// Button Settings
		button_image_url : "images/SmallSpyGlassWithTransperancy_17x18.png",
		button_placeholder_id : "spanButtonPlaceholder",
		button_width: 180,
		button_height: 18,
		button_text : '<span class="button">Select Images <span class="buttonSmall">(2 MB Max)</span></span>',
		button_text_style : '.button { font-family: Helvetica, Arial, sans-serif; font-size: 12pt; } .buttonSmall { font-size: 10pt; }',
		button_text_top_padding: 0,
		button_text_left_padding: 18,
		button_window_mode: SWFUpload.WINDOW_MODE.TRANSPARENT,
		button_cursor: SWFUpload.CURSOR.HAND,
		
		// Flash Settings
		flash_url : "../swfupload/swfupload.swf",
		
		custom_settings : {
			thumbnailContainer : document.getElementById("thumbnails")
		},

		// Debug Settings
		debug: true
	});
};

function fileQueued(file) {
	ShowPreview.call(this, file.id);
}

function fileQueueError(file, errorCode, message) {
	try {
		switch (errorCode) {
			case SWFUpload.QUEUE_ERROR.ZERO_BYTE_FILE:
				errorName = "You have attempted to queue too many files.";
				break;
			case SWFUpload.QUEUE_ERROR.QUEUE_LIMIT_EXCEEDED:
				errorName = "You've selected too many files.";
				break;
			case SWFUpload.QUEUE_ERROR.FILE_EXCEEDS_SIZE_LIMIT:
				errorName = file.name + " is too big.";
				break;
			case SWFUpload.QUEUE_ERROR.INVALID_FILETYPE:
				errorName = "You selected an invalid type of file.";
				break;
			default:
				alert(file.name + " could not be added to the Queue");
				break;
		}
	} catch (ex) {
		this.debug(ex);
	}

}

function ShowPreview(id) {
	var placeHolder = this.customSettings.thumbnailContainer.appendChild(document.createElement("span"));

	var preview = new SWFUpload.Preview({
		flash_url : "../swfupload/preview.swf",
		preview_placeholder : placeHolder,
		preview_loaded_handler : function () { PreviewLoadedHandler.call(this, id); },
		debug : true,
		width : 200,
		height: 200,
		resize_to_fit : true
	});
}
function PreviewLoadedHandler(id) {
	this.getPreview(swfu.movieName, id, this.settings.width, this.settings.height);
}

