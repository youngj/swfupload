package {
	import flash.display.Bitmap;
	import flash.display.Sprite;
	import flash.display.Loader;
	import flash.display.Stage;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.AsyncErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.StatusEvent;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.LocalConnection;
	import flash.external.ExternalInterface;
	import flash.utils.ByteArray;
	import flash.events.Event;
	import flash.system.Security;
	import flash.filters.BlurFilter;
	import flash.filters.BitmapFilterQuality;
	import flash.display.BitmapData;
	
	public class Preview extends Sprite {
		// Cause SWFUpload to start as soon as the movie starts
		public static function main():void
		{
			var preview:Preview = new Preview();
		}
		

		private const build_number:String = "Preview 0.2";
		private var movieName:String = "";
		private var debugEnabled:Boolean = false;
		
		// Callbacks
		private var flashReady_Callback:String;
		private var fileDialogStart_Callback:String;
		private var resize_Callback:String;
		private var complete_Callback:String;
		private var debug_Callback:String;
		private var cleanUp_Callback:String;
		
		private var imageLoader:Loader = null;
		
		
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
			this.stage.scaleMode = StageScaleMode.NO_SCALE;
			this.stage.addEventListener(Event.RESIZE, function anonResize(e:Event):void {
				// Had to do a closure because (unlike the other events) 'this' in the resize
				// event handler didn't reference the Preview object
				self.HandleResize(e);
			});
			
			// Get the movie name
			try {
				this.movieName = root.loaderInfo.parameters.movieName;
			} catch (ex:Object) {
				this.movieName = "";
			}

			try {
				this.debugEnabled = root.loaderInfo.parameters.debug == "true" ? true : false;
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
			this.resize_Callback             = "SWFUpload.Preview.instances[\"" + this.movieName + "\"].setPreviewDimensionsCallback";
			this.complete_Callback           = "SWFUpload.Preview.instances[\"" + this.movieName + "\"].previewComplete";
			this.debug_Callback              = "SWFUpload.Preview.instances[\"" + this.movieName + "\"].debug";
			this.cleanUp_Callback            = "SWFUpload.Preview.instances[\"" + this.movieName + "\"].cleanUp";
			
			this.SetupExternalInterface();
			
			this.Debug("Stage Size:" + this.stage.stageWidth + " by " + this.stage.stageHeight);
			this.Debug("Preview Init Complete: " + this.movieName);

			try {
				var imgS:ImageShare = new ImageShare();
				imgS.addEventListener(StatusEvent.STATUS, this.FlushStatus);
				imgS.PreFlush();
			} catch (err:Error) {
				this.FlushStatus(new StatusEvent(StatusEvent.STATUS, false, false, ImageShare.FAILED));
			}
		}
		
		private function FlushStatus(e:StatusEvent):void {
			var previewSupported:Boolean = e.code === ImageShare.SUCCESS;
			ExternalCall.Generic(this.flashReady_Callback, previewSupported);
		}

		private function HandleResize(e:Event):void {
			var stageRatio:Number = this.stage.stageWidth / this.stage.stageHeight;
			var imgRatio:Number = this.imageLoader.width / this.imageLoader.height;

			if (stageRatio > imgRatio) {
				this.imageLoader.height = this.stage.stageHeight;
				this.imageLoader.scaleX = this.imageLoader.scaleY;
			} else {
				this.imageLoader.width = this.stage.stageWidth;
				this.imageLoader.scaleY = this.imageLoader.scaleX;
			}
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
		
		private function LoadImage(fileID:String):Boolean {
			try {
				this.Debug("Beginning load of file " + fileID);
				var imageData:* = ImageShare.GetImage(this.movieName, fileID);

				if (!(imageData is ByteArray)) {
					// FIXME -- trigger previewError
					this.Debug("Image data is missing: Keys: " + imageData);
					return false;
				}
				
				if (this.imageLoader != null) {
					this.imageLoader.unload();
					this.imageLoader = null;
				}
				
				this.imageLoader = new Loader();
				imageLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, this.ImageLoaderComplete);
				
				imageLoader.loadBytes(imageData);
			} catch (ex:Error) {
				// FIXME -- trigger previewError
				this.Debug(ex.name + ":" + ex.message + ":" + ex.getStackTrace());
			}
			
			return true;
		}

		private function ImageLoaderComplete(e:Event):void {
			try {
				e.target.removeEventListener(Event.COMPLETE, this.ImageLoaderComplete);
				var loader:Loader = Loader(e.target.loader);
				Bitmap(loader.content).smoothing = true;
				this.Debug("Image size: " + loader.width + " by " + loader.height);
				
				this.stage.addChild(loader);
				this.HandleResize(null);
				
				ExternalCall.Simple(this.complete_Callback);
			} catch (err:Error)
			{
				// FIXME -- trigger previewError
			}
		}
		
		private function Debug(msg:String):void {
			try {
				if (this.debugEnabled) {
					var lines:Array = msg.split("\n");
					for (var i:Number=0; i < lines.length; i++) {
						lines[i] = "PREVIEW DEBUG (" + this.movieName + "): " + lines[i];
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
