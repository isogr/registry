import path from 'path'

import { itemClassConfiguration } from '@riboseinc/paneron-extension-geodetic-registry/registryConfig';


const DATASET_ROOT = path.join(__dirname, 'gr-registry');


const contentSummaryHTML = `
<p>
The ISO Geodetic Registry is a structured database of coordinate reference systems (CRS) and transformations
that is accessible through this online registry system. The Register includes only systems and transformations of international application.
It does not include all possible coordinate reference systems and transformations.
</p>
<p>
This Registry is provided under the auspices of <a href="https://committee.iso.org/home/tc211">ISO Technical Committee 211</a>
on geographic information/geomatics and conforms to ISO standards
<a href="https://www.iso.org/standard/41126.html">ISO 19111:2007</a> (Spatial referencing by coordinates),
<a href="https://www.iso.org/standard/67252.html">ISO 19127:2019</a> (Geodetic register)
and <a href="https://www.iso.org/standard/54721.html">ISO 19135-1:2015</a> (Procedures for item registration -- Part 1: Fundamentals).
</p>
`;

const usageNoticeHTML = `
<p>
The Registry may be used free of charge but its use is subject to acceptance of the <a href="https://geodetic.isotc211.org/terms">Terms of Use</a>.
Use of the Registry implies acceptance of these Terms of Use. Users of the Registry may query and view data and generate reports via anonymous guest access. Users may also submit proposals for new additions or clarifications to the registry.
</p>
<p>
The Registry also provides a web service interface, allowing geospatial software to query and retrieve information from the Register. Information on using the web services is available in the <a href="https://iso-tc211.github.io/iso-geodetic-register-docs/">Registry user's guide</a>.
</p>
`;

const sponsorsSupportersHTML = `
<p>
The ISO Geodetic Register is made available to the public free-of-charge with financial support given by the sponsors including:
</p>
<ul style="padding: 0; list-style: none; display: grid; grid-gap: 10px; grid-column: 1; text-align: center;">
  <li><a href="https://www.nrcan.gc.ca/"><img alt="Natural Resources Canada" src="https://user-images.githubusercontent.com/11865/128666171-6468f5ad-aa32-43da-98ca-47b074de4b55.png" style="height: 80px"/></a></li>
  <li><a href="https://www.ign.fr/"><img alt="Institut national de l'information géographique et forestière" src="https://user-images.githubusercontent.com/11865/128666318-e8f59cbc-06d9-457d-b38d-c30a8ffb4352.png" style="height: 80px"/></a></li>
  <li><a href="https://www.kartverket.no/"><img alt="Kartverket" src="https://camo.githubusercontent.com/e713dd92a4568166edfaf0694dad56ad618d73e1380430af834a13da73fe948c/68747470733a2f2f7777772e6b6172747665726b65742e6e6f2f676c6f62616c6173736574732f6f6d2d6b6172747665726b65742f6b6172747665726b736c6f676f2f6b6172747665726b65745f6c696767656e64655f7765622e737667" style="height: 60px"/></a></li>
  <li><a href="https://www.ribose.com/"><img alt="Ribose" src="https://github.com/ISO-TC211/jekyll-theme-isotc211/raw/master/assets/logo-ribose.svg" style="height: 50px"/></a></li>
</ul>
`;

const contactNoticeHTML = `
If you encounter issues or have any questions about the ISO Geodetic Register, please use the <a href="https://geodetic.isotc211.org/feedback">Feedback</a> page to submit them. A member of the team will reach out to you directly.
`;

const registrationAuthorityNoticeHTML = `
Ribose is appointed as Registration Authority of the ISO Geodetic Register by ISO in 2019 in accordance to ISO/TMB resolution 4/2019 and ISO/TC 211 Resolution 912. As Registration Authority, Ribose is responsible for providing registration services for the ISO Geodetic Register in relation to the <a href="https://www.iso.org/standard/67252.html">ISO 19127</a> International Standard.
`;

export default {
  entry: path.join(__dirname, 'src', 'index.jsx'),
  
  getRoutes: async () => {
    return [
    ]
  },
  plugins: [
    [
      '@riboseinc/react-static-plugin-paneron-registry',
      {
        datasetSourcePath: DATASET_ROOT,
        iconURL: 'https://isotc211.geolexica.org/assets/logo-iso-noninverted.svg',
        urlPrefix: '',
        itemClassConfiguration,
        extraContent: {
          contentSummaryHTML,
          usageNoticeHTML,
          sponsorsSupportersHTML,
          contactNoticeHTML,
          registrationAuthorityNoticeHTML,
        },
        subregisters: {},
        itemClassPageTemplate: 'src/ItemClassPage',
        itemPageTemplate: 'src/ItemPage',
        subregisterPageTemplate: 'src/SubregisterPage',
        homePageTemplate: 'src/HomePage',
      },
    ],
    require.resolve('react-static-plugin-reach-router'),
    [
      'react-static-plugin-file-watch-reload',
      {
        paths: [`${DATASET_ROOT}/**/*`],
      },
    ],
  ],
};
