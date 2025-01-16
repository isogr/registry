
// <!-- Google tag (gtag.js) -->
// <script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
// <script>
//   window.dataLayer = window.dataLayer || [];
//   function gtag(){dataLayer.push(arguments);}
//   gtag('js', new Date());

//   gtag('config', 'G-XXXXXXXXXX');
// </script>

/**
 * Load the Google Tag Manager
 * See: https://gist.github.com/james2doyle/28a59f8692cec6f334773007b31a1523
 */
(function() {
  'use strict';

  const logLabel = 'ga.js: ';

  const log = (...obj) => console.log(logLabel, ...obj);
  const warn = (...obj) => console.warn(logLabel, ...obj);
  const error = (...obj) => console.error(logLabel, ...obj);
  const debug = (...obj) => console.debug(logLabel, ...obj);

  const loadScript = (src) => {
    return new Promise((resolve, reject) => {
      const scriptTag = document.createElement('script');
      let hasResolved = false;
      scriptTag.async = true;
      scriptTag.onload = resolve;
      scriptTag.onerror = function(err) {
        warn('Failed to load script:', src);
        reject(err, scriptTag);
      };

      scriptTag.onload = scriptTag.onreadystatechange = function() {
        debug('scriptTag readyState = ', this.readyState);
        if (!hasResolved && (!this.readyState || this.readyState === 'complete')) {
          hasResolved = true;
          resolve();
        }
      };
      scriptTag.src = src;
      const firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentElement.insertBefore(scriptTag, firstScriptTag);
    });
  }

  /**
   * gaMeasurementId can either be replaced with `sed` before building with site-builder,
   * or it can be loaded via a JSON file served at /resources/js/ga.json,
   * which is expected to be an Object,
   * with the token under the key "gaMeasurementId".
   */
  let gaMeasurementId = 'G-RRRRRRRRRR';
  const gaMeasurementIdSrc = '/resources/js/ga.json';

  /**
   * Load Google Analytics Measurement ID
   * from a pre-determined endpoint, i.e. /resources/js/ga.json
   */
  const loadAnalyticsIdResp = async () => {
    return await fetch(gaMeasurementIdSrc).then(
      (resp) => resp.json()
    )
  };

  /**
   * Load Google Analytics tag
   */
  const loadAnalytics = async () => {

    /** This regex acts as some sort of guard. */
    if (/G-[A-Z0-9]{10}/.test(gaMeasurementId)) {

      /**
       * Load GA measurement ID dynamically
       * if the value is uninitialized.
       */
      if (/G-R{10}/.test(gaMeasurementId)) {
        const gaMeasurementIdResp = await loadAnalyticsIdResp();
        // debug('Got gaMeasurementIdResp', gaMeasurementIdResp);
        gaMeasurementId = gaMeasurementIdResp.gaMeasurementId;
        // debug('Got gaMeasurementId', gaMeasurementId);

        if (!/G-[A-Z0-9]{10}/.test(gaMeasurementId ?? '')) {
          warn('Failed to load GA Measurement ID.  Got ', gaMeasurementId, 'Aborting.');
          return;
        }
      }

      const srcs = [
        `https://www.googletagmanager.com/gtag/js?id=${gaMeasurementId}`,
        `/resources/js/gtag-${gaMeasurementId}.js`, // fallback cache
      ];

      let i = 0;
      loadScriptErrorFallback(
        srcs[i],
        // nextSrcFn:
        () => {
          return srcs[++i];
        },
        // then:
        () => {
          globalThis.dataLayer = globalThis.dataLayer || [];
          function gtag() { dataLayer.push(arguments); }
          gtag('js', new Date());
          gtag('config', gaMeasurementId);
        },
        // errorCallBack:
        // Set to `null`,
        // to let loadScriptErrorFallback try to load the next src.
        null,
        // finalErrorCallBack:
        (err) => {
          warn('Failed to load Google Tag Manager.', err);
          warn('No tracking will be done.');
        },
      );
    }
  };

  /**
   * Iterate over the `srcs` and try to load the script.
   * If it fails, tries the next `src`.
   * @param src String the URL of the script
   * @param nextSrcFn Function to return the next `src`, if available
   * @param errorCallBack Function to run when a script fails to load
   * @param finalErrorCallBack Function to run when all scripts fail to load
   */
  const loadScriptErrorFallback = (src, nextSrcFn, then, errorCallBack, finalErrorCallBack) => {
    debug('Trying to load script:', src);
    return loadScript(src).then(then, (err) => {
      if (typeof errorCallBack === 'function') {
        errorCallBack(err);
      }

      if (typeof nextSrcFn === 'function') {
        const nextSrc = nextSrcFn();
        debug('  next to try', nextSrc);
        if (typeof nextSrc !== 'undefined') {
          loadScriptErrorFallback(nextSrc, nextSrcFn, then, errorCallBack, finalErrorCallBack);
          // Re-throw error so the chained-then will not run.
          throw err;
        }
      }

      if (typeof finalErrorCallBack === 'function') {
        finalErrorCallBack();
        throw err;
      }
    }).then(() => {
      debug('Script loaded successfully:', src);
    }, () => {});
  }

  loadAnalytics();

})();
