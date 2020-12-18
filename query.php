<?php
if ($_POST && $_POST['address']) {
	$result = shell_exec("/root/rbl/php-check-rbl " . escapeshellarg($_POST['address']), $output); 
	echo $output;
}
?>
<html>
<body>
<form action="query.php">
<input type="text" name="address" />
<input type="submit" value="Query" />
</form>
</body>
</html>
