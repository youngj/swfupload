package {
	import flash.display.Sprite;
	import flash.display.Loader;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.StatusEvent;
	import flash.net.LocalConnection;
	import flash.external.ExternalInterface;
	import flash.utils.ByteArray;
	import flash.events.Event;
	import flash.system.Security;
	
	public class Preview extends Sprite {
		// Cause SWFUpload to start as soon as the movie starts
		public static function main():void
		{
			var preview:Preview = new Preview();
		}
		

		private const build_number:String = "Preview 0.1";
		private var movieName:String = "";
		private var debugEnabled:Boolean = false;
		
		private var hasCalledFlashReady:Boolean = false;
		
		// Callbacks
		private var flashReady_Callback:String;
		private var fileDialogStart_Callback:String;
		private var resize_Callback:String;
		private var complete_Callback:String;
		private var debug_Callback:String;
		private var cleanUp_Callback:String;
		
		
		private var imageLoader:Loader;
		
		
		public function Preview() {
			// Do the feature detection.  Make sure this version of Flash supports the features we need. If not abort initialization.
			if (!flash.net.LocalConnection || !flash.display.Loader || !flash.external.ExternalInterface || !flash.external.ExternalInterface.available) {
				return;
			}

			var self:Preview = this;
			Security.allowDomain("*");	// Allow uploading to any domain
			
			// Keep Flash Player busy so it doesn't show the "flash script is running slowly" error
			var counter:Number = 0;
			root.addEventListener(Event.ENTER_FRAME, function ():void { if (++counter > 100) counter = 0; });

			// Setup the stage
			this.stage.align = StageAlign.TOP_LEFT;
			this.stage.scaleMode = StageScaleMode.NO_BORDER;
			
			// Setup the image
			this.imageLoader = new Loader();
			this.stage.addChild(this.imageLoader);

			
			// Get the movie name
			try {
				this.movieName = root.loaderInfo.parameters.movieName;
			} catch (ex:Object) {
				this.movieName = "";
			}

			try {
				this.debugEnabled = root.loaderInfo.parameters.debugEnabled == "true" ? true : false;
			} catch (ex:Object) {
				this.debugEnabled = false;
			}
			
			// **Configure the callbacks**
			// The JavaScript tracks all the instances of SWFUpload on a page.  We can access the instance
			// associated with this SWF file using the movieName.  Each callback is accessible by making
			// a call directly to it on our instance.  There is no error handling for undefined callback functions.
			// A developer would have to deliberately remove the default functions,set the variable to null, or remove
			// it from the init function.
			this.flashReady_Callback         = "SWFUpload.Preview.instances[\"" + this.movieName + "\"].flashReady";
			this.resize_Callback             = "SWFUpload.Preview.instances[\"" + this.movieName + "\"].setPreviewDimensions";
			this.complete_Callback           = "SWFUpload.Preview.instances[\"" + this.movieName + "\"].previewComplete";
			this.debug_Callback              = "SWFUpload.Preview.instances[\"" + this.movieName + "\"].debug";
			this.cleanUp_Callback            = "SWFUpload.Preview.instances[\"" + this.movieName + "\"].cleanUp";
			
			this.SetupExternalInterface();
			
			this.Debug("Preview Init Complete: " + this.movieName);

			ExternalCall.Simple(this.flashReady_Callback);
			this.hasCalledFlashReady = true;
		}

		private function SetupExternalInterface():void {
			try {
				ExternalInterface.addCallback("LoadImage", this.LoadImage);
				ExternalInterface.addCallback("SetDebugEnabled", this.SetDebugEnabled);
			} catch (ex:Error) {
				this.Debug("Callbacks where not set: " + ex.message);
				return;
			}
			
			ExternalCall.Simple(this.cleanUp_Callback);
		}
		
		private function SetDebugEnabled(debug:Boolean):void {
			this.debugEnabled = debug;
		}
		
		private function ShowImage():void {
			this.imageLoader.loadBytes(this.imageData);
			this.receivingFileID = "";
			this.imageData = null;
		}
		private function ImageLoaderCompleteHandler(e:Event):void {
			ExternalCall.Generic(this.resize_Callback, { "width": this.imageLoader.width, "height" : this.imageLoader.height });
			ExternalCall.Simple(this.complete_Callback);
		}
		
		private function LoadImage(swfUploadMovieName:String, file_id:String, width:int, height:int, encoder:int, quality:int):void {
			// Connect to the SWFUpload movie.  Tell it to send the file and what the server name is
			var receiver:LocalConnection = new LocalConnection();
			receiver.client = this;
			receiver.connect(this.movieName);
			
			var notify:LocalConnection = new LocalConnection();
			notify.send(swfUploadMovieName, "RequestImage", this.movieName, file_id, width, height, encoder, quality);
		}
		
		private var receivingFileID:String = "";
		private var imageData:ByteArray;
		public function StartImageSend(file_id:String):void {
			if (this.receivingFileID === "") {
				this.receivingFileID = file_id;
				this.imageData = new ByteArray();
			}
		}
		public function ReceiveImageChunk(file_id:String, data:ByteArray):void {
			if (file_id === this.receivingFileID) {
				this.imageData.writeBytes(data);
			}
		}
		public function EndImageSend(file_id:String):void {
			if (file_id === this.receivingFileID) {
				this.ShowImage();
			}
		}
		
		private function Debug(msg:String):void {
			try {
				if (this.debugEnabled) {
					var lines:Array = msg.split("\n");
					for (var i:Number=0; i < lines.length; i++) {
						lines[i] = "SWF DEBUG: " + lines[i];
					}
						ExternalCall.Debug(this.debug_Callback, lines.join("\n"));
				}
			} catch (ex:Error) {
				// pretend nothing happened
				trace(ex);
			}
		}
		

	}
}
