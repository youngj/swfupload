<?php
	/* Note: This thumbnail creation script requires the GD PHP Extension.  
		If GD is not installed correctly PHP does not render this page correctly
		and SWFUpload will get "stuck" never calling uploadSuccess or uploadError
	 */

	// Get the session Id passed from SWFUpload. We have to do this to work-around the Flash Player Cookie Bug
	if (isset($_POST["PHPSESSID"])) {
		session_id($_POST["PHPSESSID"]);
	}

	session_start();
	ini_set("html_errors", "0");

	// Check the upload
/*	if (!isset($_FILES["Filedata"]) || !is_uploaded_file($_FILES["Filedata"]["tmp_name"]) || $_FILES["Filedata"]["error"] != 0) {
		echo "ERROR:invalid upload";
		exit(0);
	}
*/

	$fileData = $_POST["Filedata"];

	// Use a output buffering to load the image into a variable
	ob_start();
	echo $fileData;
	$imagevariable = ob_get_contents();
	ob_end_clean();

	$file_id = md5(rand()*100000);
	
	$_SESSION["file_info"][$file_id] = $imagevariable;

	echo "FILEID:" . $file_id;	// Return the file id to the script
	
?>