package  
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.StatusEvent;
	import flash.utils.ByteArray;
	import flash.net.SharedObject;
	import flash.net.SharedObjectFlushStatus;
	import flash.events.NetStatusEvent;
// Tips from http://jaycsantos.com/flash/the-trick-to-using-sharedobject/

[Event(name=StatusEvent.STATUS, type="StatusEvent")]

public class ImageShare extends EventDispatcher
	{
		
		public function ImageShare() 
		{
		}
		
		public static function StoreImage(movieName:String, fileID:String, data:ByteArray):void {
			try {
				var mySo:SharedObject = SharedObject.getLocal( "swfupload|preview", "/");
				mySo.data[movieName + "|" + fileID] = data;
				var flushResult:SharedObjectFlushStatus = mySo.flush(data.length);
				
				// http://livedocs.adobe.com/flex/3/langref/flash/net/SharedObject.html#getLocal()
				if (flushStatus != null) {
					switch (flushStatus) {
						case SharedObjectFlushStatus.PENDING:
							mySo.addEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);
							break;
						case SharedObjectFlushStatus.FLUSHED:
							dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, "Success"));
							break;
					}
				} else {
					dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, "Failed"));
				}
				
			} catch (ex:Error) {
				dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, "Failed"));
			}
			
			return false;
		}
		
		public static function GetImage(movieName:String, fileID:String):ByteArray {
			try {
				var mySo:SharedObject = SharedObject.getLocal( "swfupload|preview", "/");
				if (mySo.data[movieName + "|" + fileID]) {
					var data:ByteArray = mySo.data[movieName + "|" + fileID];
					delete mySo.data[movieName + "|" + fileID];
					return data;
				}
			} catch (ex:Error) { }
			
			return null;
		}
		
		private static function onFlushStatus(event:NetStatusEvent):void {
            event.target.removeEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);
            switch (event.info.code) {
                case "SharedObject.Flush.Success":
					dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, "Success"));
                    break;
                case "SharedObject.Flush.Failed":
					dispatchEvent(new StatusEvent(StatusEvent.STATUS, false, false, "Failed"));
                    break;
            }

        }
		
	}

}