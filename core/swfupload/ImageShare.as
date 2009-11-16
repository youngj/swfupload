package  
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.StatusEvent;
	import flash.events.SyncEvent;
	import flash.system.Security;
	import flash.system.SecurityPanel;
	import flash.utils.ByteArray;
	import flash.net.SharedObject;
	import flash.net.SharedObjectFlushStatus;
	import flash.events.NetStatusEvent;
// Tips from http://jaycsantos.com/flash/the-trick-to-using-sharedobject/

[Event(name=StatusEvent.STATUS, type="StatusEvent")]

	public class ImageShare extends EventDispatcher
	{
		public static const SUCCESS:String = "Success";
		public static const FAILED:String = "Failed";
		
		public function ImageShare() 
		{
		}
		
		public static function GetSharedObjectName():String {
			return "swfupload_preview";
		}
		public static function GetDataStoreName(movieName:String, fileID:String):String {
			return movieName + "_" + fileID;
		}
		
		private var mySo:SharedObject;
		public function StoreImage(movieName:String, fileID:String, data:ByteArray):void {
			try {
				this.mySo = SharedObject.getLocal(GetSharedObjectName(), "/");
				this.mySo.addEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);
				this.mySo.data[GetDataStoreName(movieName, fileID)] = data;

				var flushResult:String = this.mySo.flush();
				
				// http://livedocs.adobe.com/flex/3/langref/flash/net/SharedObject.html#getLocal()
				if (flushResult != null) {
					switch (flushResult) {
						case SharedObjectFlushStatus.FLUSHED:
							dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, ImageShare.SUCCESS));
							break;
						case SharedObjectFlushStatus.PENDING:
						default:
							break;
					}
				} else {
					this.mySo.removeEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);
					this.mySo = null;
					dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, ImageShare.FAILED));
				}
				
			} catch (ex:Error) {
				dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, ImageShare.FAILED, ex.message));
				if (this.mySo != null) {
					this.mySo.removeEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);
					this.mySo = null;
				}
			}
		}
		
		public static function GetImage(movieName:String, fileID:String):* {
			var mySo:SharedObject = SharedObject.getLocal(GetSharedObjectName(), "/");
			if (GetDataStoreName(movieName, fileID) in mySo.data) {
				var data:ByteArray = mySo.data[GetDataStoreName(movieName, fileID)];
				mySo.data[GetDataStoreName(movieName, fileID)] = null;
				delete mySo.data[GetDataStoreName(movieName, fileID)];
				mySo.flush();
				return data;
			} else {
				var keys:String = "";
				for (var key:String in mySo.data) 
				{
					keys += key + ", ";
				}

				return keys;
			}
		}
		
		private function onFlushStatus(event:NetStatusEvent):void {
            try {
				event.target.removeEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);
				
				switch (event.info.code) {
					case "SharedObject.Flush.Success":
						dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, ImageShare.SUCCESS));
						break;
					case "SharedObject.Flush.Failed":
						dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, ImageShare.FAILED));
						break;
				}
				
				this.mySo = null;
			} catch (ex:Error) {
				dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, ImageShare.FAILED, ex.message));
			}
        }
				
		public function PreFlush():void {
			try {
				this.mySo = SharedObject.getLocal(GetSharedObjectName(), "/");
				this.mySo.addEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);

				var flushResult:String = this.mySo.flush(10485760);
				
				// http://livedocs.adobe.com/flex/3/langref/flash/net/SharedObject.html#getLocal()
				if (flushResult != null) {
					switch (flushResult) {
						case SharedObjectFlushStatus.FLUSHED:
							dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, ImageShare.SUCCESS));
							break;
						case SharedObjectFlushStatus.PENDING:
						default:
							break;
					}
				} else {
					this.mySo.removeEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);
					this.mySo = null;
					dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, ImageShare.FAILED));
				}
				
			} catch (ex:Error) {
				dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, ImageShare.FAILED, ex.message));
				if (this.mySo != null) {
					this.mySo.removeEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);
					this.mySo = null;
				}
			}
		}
		
		
	}

}