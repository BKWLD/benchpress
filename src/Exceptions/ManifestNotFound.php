<?php namespace Bkwld\Camo\Exceptions;

class ManifestNotFound extends \Exception
{
    protected $message = 'You probably need to run a webpack build or a build is in the middle of running. Regardless, "public/wp-content/themes/site/dist/manifest.json" could not be found.';
}
