// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { useWalletKit } from '@mysten/wallet-kit';
import { Fragment, type ReactNode } from 'react';
import { createBrowserRouter, Navigate, useLocation, useParams } from 'react-router-dom';

import Root from './Root';
import { AboutPage } from '../pages/AboutPage';
import { AccessoryShopPage } from '../pages/AccessoriesShopPage';
import { AccessoryPage } from '../pages/AccessoryPage';
import { CollectionPage } from '../pages/CollectionPage';
import { FaqPage } from '../pages/FaqPage';
import { FrenPage } from '../pages/FrenPage';
import { HomePage } from '../pages/HomePage';
// import { HowToPage } from '../pages/HowToPage';
import { MintPage } from '../pages/MintPage';
import { NotFoundPage } from '../pages/NotFoundPage';
import { StatusPage } from '../pages/StatusPage';
import { SuiFrenImgPage } from '../pages/SuiFrenImgPage';

import { MixPage } from '~/pages/MixPage/MixPage';

function RedirectWithId({ base }: { base: string }) {
	const params = useParams();
	const { search } = useLocation();
	return <Navigate to={`/${base}/${params.id}${search}`} replace />;
}

function ResetPageOnWalletChange({ children }: { children: ReactNode }) {
	const { currentAccount } = useWalletKit();
	return <Fragment key={currentAccount?.address}>{children}</Fragment>;
}

function getRouterChildren() {
	return [
		{
			path: '',
			element: <HomePage />,
		},
		{
			path: 'mint',
			element: <MintPage />,
		},
		{
			path: 'collection/:tab?',
			element: <CollectionPage />,
		},
		// @todo: add back when the page is completed
		// {
		//     path: 'how-to',
		//     element: <HowToPage />,
		// },
		{
			path: 'mix',
			element: (
				<ResetPageOnWalletChange>
					<MixPage />
				</ResetPageOnWalletChange>
			),
		},
		{
			path: 'capy/:id',
			element: <RedirectWithId base="fren" />,
		},
		{
			path: 'fren/:id',
			element: <FrenPage />,
		},
		{
			path: 'status',
			element: <StatusPage />,
		},
		{
			path: 'faq',
			element: <FaqPage />,
		},
		{
			path: 'about',
			element: <AboutPage />,
		},
		{
			path: 'accessory/:name',
			element: <AccessoryPage />,
		},
		{
			path: 'accessory-shop',
			element: <AccessoryShopPage />,
		},
		{
			path: '*',
			element: <NotFoundPage />,
		},
	];
}

export const router = createBrowserRouter([
	{
		path: '/',
		element: <Root />,
		children: getRouterChildren(),
	},
	{
		path: '/',
		children: [
			{
				path: 'suifren/:id/preview',
				element: <SuiFrenImgPage />,
			},
		],
	},
]);
