// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { MotionConfig } from 'framer-motion';
import { Outlet } from 'react-router-dom';

import { Footer } from '../components/Footer';
import { Header } from '../components/Header';

import { Toaster } from '~/components/Toaster';
import { useCookieConsentBanner } from '~/hooks/useCookieConsentBanner';
import { useInitialPageView } from '~/hooks/useInitialPageView';
import { persistableStorage } from '~/utils/analytics/amplitude';

export default function Root() {
	useCookieConsentBanner(persistableStorage, {
		cookie_name: 'suifrens_cookie_consent',
		onBeforeLoad: async () => {
			await import('../cookieConsent.css');
			document.body.classList.add('cookie-consent-theme');
		},
	});

	useInitialPageView();

	return (
		<div className="font-calibre font-thin" style={{ background: 'rgba(255, 255, 255, 0.97)' }}>
			<MotionConfig reducedMotion="user">
				<Header />
				<Outlet />
				<Footer />
				<Toaster />
			</MotionConfig>
			{import.meta.env.DEV && <ReactQueryDevtools />}
		</div>
	);
}
