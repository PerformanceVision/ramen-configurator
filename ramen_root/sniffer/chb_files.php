-- vim: ft=sql expandtab
<? include "chb_v30.php" ?>

PARAMETERS
  files_prefix DEFAULTS TO "/srv/nova/ramen/*.*.",
  files_compressed DEFAULTS TO false,
  files_delete DEFAULTS TO true;

<?
foreach ($LAYERS as $layer => $ramen_function_name) {
  $content_path = get_content_path($layer);
  $content = file_get_contents($content_path);
?>
DEFINE LAZY '<?=$ramen_function_name?>_ext' AS
  READ FROM
    FILES files_prefix || "<?=$layer?>_*v30.*chb" || (IF files_compressed THEN ".lz4" ELSE "")
      PREPROCESSED WITH (IF files_compressed THEN "lz4 -d -c" ELSE "")
      THEN DELETE IF files_delete
    AS ROWBINARY (
      <?=$content?>
  )
  EVENT STARTING AT capture_begin * 1e-6
    AND STOPPING AT capture_end * 1e-6;
<?
}
?>

<? include 'adapt_chb_types.ramen' ?>
