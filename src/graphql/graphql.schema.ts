
/*
 * -------------------------------------------------------
 * THIS FILE WAS AUTOMATICALLY GENERATED (DO NOT MODIFY)
 * -------------------------------------------------------
 */

/* tslint:disable */
/* eslint-disable */

export interface IQuery {
    capitalCities(): Nullable<CapitalCityCollection> | Promise<Nullable<CapitalCityCollection>>;
    hannibalRoute(): Nullable<HannibalRouteCollection> | Promise<Nullable<HannibalRouteCollection>>;
    pointRoute(): Nullable<PointRouteCollection> | Promise<Nullable<PointRouteCollection>>;
}

export interface CapitalCityCollection {
    type?: Nullable<string>;
    features?: Nullable<Nullable<CapitalCityFeature>[]>;
}

export interface CapitalCityFeature {
    type?: Nullable<string>;
    geometry?: Nullable<GeometryPoint>;
    properties?: Nullable<CapitalCityProperties>;
}

export interface HannibalRouteCollection {
    type?: Nullable<string>;
    features?: Nullable<Nullable<HannibalRouteFeature>[]>;
}

export interface HannibalRouteFeature {
    type?: Nullable<string>;
    geometry?: Nullable<GeometryLineString>;
    properties?: Nullable<HannibalRouteProperties>;
}

export interface PointRouteCollection {
    type?: Nullable<string>;
    features?: Nullable<Nullable<PointRouteFeature>[]>;
}

export interface PointRouteFeature {
    type?: Nullable<string>;
    geometry?: Nullable<GeometryPoint>;
    properties?: Nullable<PointRouteProperties>;
}

export interface GeometryPoint {
    type?: Nullable<string>;
    coordinates?: Nullable<Nullable<number>[]>;
}

export interface GeometryLineString {
    type?: Nullable<string>;
    coordinates?: Nullable<Nullable<Nullable<number>[]>[]>;
}

export interface CapitalCityProperties {
    name?: Nullable<string>;
    description?: Nullable<string>;
    empire?: Nullable<string>;
}

export interface HannibalRouteProperties {
    description?: Nullable<string>;
}

export interface PointRouteProperties {
    description?: Nullable<string>;
}

type Nullable<T> = T | null;
