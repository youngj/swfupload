package {
	import flash.display.Bitmap;
	import flash.display.Sprite;
	import flash.display.Loader;
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
		
		private var resizedBmp:Bitmap = null;
		
		
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
			
			this.Debug("Stage Size:" + this.stage.width + " by " + this.stage.height);
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
			try {
				this.Debug("Loading received image data");
				if (this.receiver != null) {
					try {
						this.receiver.close();
					} catch (ex:Error) {}
					this.receiver = null;
				}
				this.receivingFileID = "";


				var imageLoader:Loader = new Loader();
				imageLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, this.ImageLoaderComplete);
				
				imageLoader.loadBytes(this.imageData);
				this.imageData = null;
			} catch (ex:Error) {
				this.Debug(ex.message);
			}
		}

		private function ImageLoaderComplete(e:Event):void {
			e.target.removeEventListener(Event.COMPLETE, this.ImageLoaderComplete);
			var loader:Loader = Loader(e.target.loader);

			this.Debug("Image size: " + loader.width + " by " + loader.height);
			var targetRatio:Number = this.maxWidth / this.maxHeight;
			var imgRatio:Number = loader.width / loader.height;
			var newHeight:Number = (targetRatio > imgRatio) ? this.maxHeight : Math.min(this.maxWidth / imgRatio, this.maxHeight);
			var newWidth:Number = (targetRatio > imgRatio) ? Math.min(imgRatio * this.maxHeight, this.maxWidth) : this.maxWidth;
			
			var resizedBmp:BitmapData = null;
			
			// Get the image data
			var bmp:BitmapData = Bitmap(loader.content).bitmapData;

			// Blur it a bit if it is sizing smaller
			if (this.maxWidth < loader.width || newHeight <= loader.height) {
				// Apply the blur filter that helps clean up the resized image result
				var blurMultiplier:Number = 1.15; // 1.25;
				var blurXValue:Number = Math.max(1, loader.width / newWidth) * blurMultiplier;
				var blurYValue:Number = Math.max(1, loader.height / newHeight) * blurMultiplier;
				
				var blurFilter:BlurFilter = new BlurFilter(blurXValue, blurYValue, int(BitmapFilterQuality.LOW));
				bmp.applyFilter(bmp, new Rectangle(0, 0, bmp.width, bmp.height), new Point(0, 0), blurFilter);
			}

			// Apply the resizing
			var matrix:Matrix = new Matrix();
			matrix.identity();
			matrix.createBox(newWidth / bmp.width, newHeight / bmp.height);

			var resizedBmpData:BitmapData = new BitmapData(newWidth, newHeight, true, 0x000000);
			resizedBmpData.draw(bmp, matrix, null, null, null, true);

			
			if (this.resizedBmp !== null) {
				this.stage.removeChild(this.resizedBmp);
				this.resizedBmp = null;
			}
			this.resizedBmp = new Bitmap(resizedBmpData);
			this.stage.addChild(this.resizedBmp);
			
			ExternalCall.Simple(this.complete_Callback);
		}
		
		private var receiver:LocalConnection = null;
		private var receivingFileID:String = "";
		private var imageData:ByteArray;
		private var maxWidth:Number;
		private var maxHeight:Number;
		
		private function LoadImage(swfUploadMovieName:String, file_id:String, width:Number, height:Number):void {
			this.Debug("Beginning request of file " + file_id + " from " + swfUploadMovieName);
			
			this.maxWidth = width;
			this.maxHeight = height;
			
			this.receivingFileID = "";	// Effectively cancels any previous previews
			
			// Connect to the SWFUpload movie.  Tell it to send the file and what the server name is
			this.receiver = new LocalConnection();
			this.receiver.client = this;
			try {
				this.receiver.connect(this.movieName);
			} catch (ex:Error) {
				this.Debug("Error starting LocalConnection server: " + ex.message);
				return;
			}
			
			try {
				var notify:LocalConnection = new LocalConnection();
				this.Debug("RequestImage");
				notify.send(swfUploadMovieName, "RequestImage", this.movieName, file_id);
			} catch (ex:Error) {
				this.Debug("Error requesting image from " + swfUploadMovieName + " : " + ex.message);
				return;
			}
		}
		
		public function StartImageSend(file_id:String):void {
			if (this.receivingFileID === "") {
				try {
					this.Debug("Starting Data receiving for " + file_id);

					this.imageData = new ByteArray();
					this.receivingFileID = file_id;
				} catch (ex:Error) {

				}
			} else {
				this.Debug("Attempted to start data send for unmatched file id " + file_id);
			}
		}
		public function ReceiveImageChunk(file_id:String, data:ByteArray):void {
			if (file_id === this.receivingFileID) {
				this.imageData.writeBytes(data);
			} else {
				this.Debug("Attempted send for unmatched file id " + file_id);
			}
		}
		public function EndImageSend(file_id:String):void {
			if (file_id === this.receivingFileID) {
				this.Debug("Finished send of " + this.imageData.length + " bytes for " + file_id);
				this.ShowImage();
			} else {
				this.Debug("Attempted end send for unmatched file id " + file_id);
			}
		}
		
		private function Debug(msg:String):void {
			try {
				if (this.debugEnabled) {
					var lines:Array = msg.split("\n");
					for (var i:Number=0; i < lines.length; i++) {
						lines[i] = "PREVIEW DEBUG: " + lines[i];
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
