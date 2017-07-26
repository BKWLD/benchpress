<?php

namespace Bkwld\Benchpress;

// Deps
use Bkwld\Benchpress\Exceptions\ManifestNotFound;

/**
 * Helpers for generating references to Webpack built assets
 */
class Webpack
{
    /**
     * Contains the parsed webpack manifest.json
     *
     * @var stdObject
     */
    protected $webpack_manifest;

    /**
     * Load the webpack manifest if found
     * @return void
     *
     * @throws Bkwld\Camo\Exceptions\ManifestNotFound;
     */
    public function loadManifest() {
        if (!$this->webpack_manifest) {
            $manifest_path = get_template_directory().'/dist/manifest.json';
            if (!file_exists($manifest_path)) throw new ManifestNotFound;
            $this->webpack_manifest = json_decode(file_get_contents($manifest_path));
        }
    }

    /**
     * Generate either a script (js) or link (css) tag using the manifest.json
     * file output by json.
     *
     * @param  string $name The webpack entry point name for the asset with it's
     *                      suffix.  For instance, if your entry config has
     *                      `app: 'bott.coffee'`, you would pass this function
     *                      'app.js'
     * @return string|void  Either a script or link HTML string.  Or nothing if
     *                      the the $name coudln't be found.
     */
    public function webpackAssetTag($name)
    {
        $this->loadManifest();

        // If the manifest contains a reference, generate a tag for it.  Otherwise
        // just use an empty string
        $tag = empty($this->assetUrl($name)) ? ''
            : $this->assetTag($type, $this->assetUrl($name));

        // Cache and return the tag
        return $tag;
    }

    /**
     * Generate a script or link tag for the provided URL
     *
     * @param  string $type "js" or "css"
     * @param  string $url  URL to an asset
     * @return string       An HTML tag linking to the URL
     */
    public function assetTag($type, $url)
    {
        switch($type) {
            case 'js': return "<script src='$url' charset='utf-8'></script>";
            case 'css': return "<link href='$url' rel='stylesheet'>";
        }
    }

    /**
     * Generate the url to the asset created by webpack
     *
     * @param  string $name The name of the asset
     * @return string|void  The string of the URL
     */
    public function assetUrl($name)
    {
        $this->loadManifest();
        list($key, $type) = explode('.', $name);
        return $this->webpack_manifest->$key->$type;
    }

}
