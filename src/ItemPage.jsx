import React from 'react';
import DefaultItemPage from '@riboseinc/react-static-plugin-paneron-registry/DefaultRegisterItemPage';
import { itemClassConfiguration } from '@riboseinc/paneron-extension-geodetic-registry/registryConfig';


export default () => (
  <DefaultItemPage itemClassConfiguration={itemClassConfiguration} />
)
