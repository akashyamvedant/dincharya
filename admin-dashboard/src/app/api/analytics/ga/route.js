import { BetaAnalyticsDataClient } from '@google-analytics/data';
import { NextResponse } from 'next/server';

// Initialize GA4 client with service account credentials
const propertyId = process.env.GA4_PROPERTY_ID;

function getClient() {
    return new BetaAnalyticsDataClient({
        credentials: {
            client_email: process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL,
            private_key: process.env.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        },
    });
}

export async function GET(request) {
    try {
        const { searchParams } = new URL(request.url);
        const type = searchParams.get('type') || 'overview';
        const days = parseInt(searchParams.get('days') || '30');

        if (!propertyId) {
            return NextResponse.json({ error: 'GA4_PROPERTY_ID not configured' }, { status: 500 });
        }

        const client = getClient();
        const property = `properties/${propertyId}`;

        switch (type) {
            case 'overview':
                return NextResponse.json(await getOverview(client, property, days));

            case 'realtime':
                return NextResponse.json(await getRealtime(client, property));

            case 'daily_users':
                return NextResponse.json(await getDailyUsers(client, property, days));

            case 'demographics':
                return NextResponse.json(await getDemographics(client, property, days));

            case 'devices':
                return NextResponse.json(await getDevices(client, property, days));

            case 'top_screens':
                return NextResponse.json(await getTopScreens(client, property, days));

            case 'events':
                return NextResponse.json(await getEvents(client, property, days));

            case 'retention':
                return NextResponse.json(await getRetention(client, property, days));

            case 'traffic_sources':
                return NextResponse.json(await getTrafficSources(client, property, days));

            default:
                return NextResponse.json({ error: `Unknown type: ${type}` }, { status: 400 });
        }
    } catch (error) {
        console.error('GA4 API Error:', error);
        return NextResponse.json({
            error: error.message || 'Failed to fetch GA4 data',
            details: error.details || null,
        }, { status: 500 });
    }
}

// ─── Overview: key metrics ──────────────────────────────────
async function getOverview(client, property, days) {
    const [response] = await client.runReport({
        property,
        dateRanges: [
            { startDate: `${days}daysAgo`, endDate: 'today' },
            { startDate: `${days * 2}daysAgo`, endDate: `${days + 1}daysAgo` }, // previous period for comparison
        ],
        metrics: [
            { name: 'activeUsers' },
            { name: 'newUsers' },
            { name: 'sessions' },
            { name: 'screenPageViews' },
            { name: 'averageSessionDuration' },
            { name: 'engagementRate' },
            { name: 'sessionsPerUser' },
            { name: 'totalUsers' },
        ],
    });

    const current = response.rows?.[0]?.metricValues || [];
    const previous = response.rows?.[1]?.metricValues || [];

    const getValue = (idx, arr) => parseFloat(arr[idx]?.value || '0');
    const calcChange = (idx) => {
        const cur = getValue(idx, current);
        const prev = getValue(idx, previous);
        if (prev === 0) return cur > 0 ? 100 : 0;
        return Math.round(((cur - prev) / prev) * 100);
    };

    return {
        activeUsers: getValue(0, current),
        newUsers: getValue(1, current),
        sessions: getValue(2, current),
        screenPageViews: getValue(3, current),
        avgSessionDuration: Math.round(getValue(4, current)),
        engagementRate: Math.round(getValue(5, current) * 100),
        sessionsPerUser: Math.round(getValue(6, current) * 100) / 100,
        totalUsers: getValue(7, current),
        changes: {
            activeUsers: calcChange(0),
            newUsers: calcChange(1),
            sessions: calcChange(2),
            screenPageViews: calcChange(3),
        },
    };
}

// ─── Realtime: live active users ───────────────────────────
async function getRealtime(client, property) {
    const [response] = await client.runRealtimeReport({
        property,
        metrics: [{ name: 'activeUsers' }],
    });

    const totalActive = parseInt(response.rows?.[0]?.metricValues?.[0]?.value || '0');

    // By country
    const [byCountry] = await client.runRealtimeReport({
        property,
        dimensions: [{ name: 'country' }],
        metrics: [{ name: 'activeUsers' }],
    });

    // By device
    const [byDevice] = await client.runRealtimeReport({
        property,
        dimensions: [{ name: 'deviceCategory' }],
        metrics: [{ name: 'activeUsers' }],
    });

    return {
        activeUsers: totalActive,
        byCountry: (byCountry.rows || []).map(r => ({
            country: r.dimensionValues[0].value,
            users: parseInt(r.metricValues[0].value),
        })).sort((a, b) => b.users - a.users).slice(0, 10),
        byDevice: (byDevice.rows || []).map(r => ({
            device: r.dimensionValues[0].value,
            users: parseInt(r.metricValues[0].value),
        })),
    };
}

// ─── Daily Users chart ─────────────────────────────────────
async function getDailyUsers(client, property, days) {
    const [response] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'date' }],
        metrics: [
            { name: 'activeUsers' },
            { name: 'newUsers' },
            { name: 'sessions' },
        ],
        orderBys: [{ dimension: { dimensionName: 'date', orderType: 'ALPHANUMERIC' } }],
    });

    return (response.rows || []).map(r => ({
        date: formatGADate(r.dimensionValues[0].value),
        activeUsers: parseInt(r.metricValues[0].value),
        newUsers: parseInt(r.metricValues[1].value),
        sessions: parseInt(r.metricValues[2].value),
    }));
}

// ─── Demographics ──────────────────────────────────────────
async function getDemographics(client, property, days) {
    const [byCountry] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'country' }],
        metrics: [{ name: 'activeUsers' }, { name: 'sessions' }],
        orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }],
        limit: 15,
    });

    const [byCity] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'city' }],
        metrics: [{ name: 'activeUsers' }],
        orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }],
        limit: 15,
    });

    const [byLanguage] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'language' }],
        metrics: [{ name: 'activeUsers' }],
        orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }],
        limit: 10,
    });

    return {
        countries: (byCountry.rows || []).map(r => ({
            country: r.dimensionValues[0].value,
            users: parseInt(r.metricValues[0].value),
            sessions: parseInt(r.metricValues[1].value),
        })),
        cities: (byCity.rows || []).map(r => ({
            city: r.dimensionValues[0].value,
            users: parseInt(r.metricValues[0].value),
        })),
        languages: (byLanguage.rows || []).map(r => ({
            language: r.dimensionValues[0].value,
            users: parseInt(r.metricValues[0].value),
        })),
    };
}

// ─── Device Breakdown ──────────────────────────────────────
async function getDevices(client, property, days) {
    const [byCategory] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'deviceCategory' }],
        metrics: [{ name: 'activeUsers' }, { name: 'sessions' }],
    });

    const [byOS] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'operatingSystem' }],
        metrics: [{ name: 'activeUsers' }],
        orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }],
        limit: 10,
    });

    const [byBrowser] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'browser' }],
        metrics: [{ name: 'activeUsers' }],
        orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }],
        limit: 10,
    });

    return {
        categories: (byCategory.rows || []).map(r => ({
            device: r.dimensionValues[0].value,
            users: parseInt(r.metricValues[0].value),
            sessions: parseInt(r.metricValues[1].value),
        })),
        operatingSystems: (byOS.rows || []).map(r => ({
            os: r.dimensionValues[0].value,
            users: parseInt(r.metricValues[0].value),
        })),
        browsers: (byBrowser.rows || []).map(r => ({
            browser: r.dimensionValues[0].value,
            users: parseInt(r.metricValues[0].value),
        })),
    };
}

// ─── Top Screens/Pages ─────────────────────────────────────
async function getTopScreens(client, property, days) {
    const [response] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'unifiedScreenName' }],
        metrics: [
            { name: 'screenPageViews' },
            { name: 'activeUsers' },
            { name: 'averageSessionDuration' },
        ],
        orderBys: [{ metric: { metricName: 'screenPageViews' }, desc: true }],
        limit: 20,
    });

    return (response.rows || []).map(r => ({
        screen: r.dimensionValues[0].value,
        views: parseInt(r.metricValues[0].value),
        users: parseInt(r.metricValues[1].value),
        avgDuration: Math.round(parseFloat(r.metricValues[2].value)),
    }));
}

// ─── Custom Events ─────────────────────────────────────────
async function getEvents(client, property, days) {
    const [response] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'eventName' }],
        metrics: [
            { name: 'eventCount' },
            { name: 'totalUsers' },
        ],
        orderBys: [{ metric: { metricName: 'eventCount' }, desc: true }],
        limit: 30,
    });

    return (response.rows || []).map(r => ({
        event: r.dimensionValues[0].value,
        count: parseInt(r.metricValues[0].value),
        users: parseInt(r.metricValues[1].value),
    }));
}

// ─── Retention: new vs returning ───────────────────────────
async function getRetention(client, property, days) {
    const [response] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'newVsReturning' }],
        metrics: [
            { name: 'activeUsers' },
            { name: 'sessions' },
            { name: 'engagementRate' },
        ],
    });

    const result = {};
    (response.rows || []).forEach(r => {
        const type = r.dimensionValues[0].value; // 'new' or 'returning'
        result[type] = {
            users: parseInt(r.metricValues[0].value),
            sessions: parseInt(r.metricValues[1].value),
            engagementRate: Math.round(parseFloat(r.metricValues[2].value) * 100),
        };
    });

    return result;
}

// ─── Traffic Sources ───────────────────────────────────────
async function getTrafficSources(client, property, days) {
    const [response] = await client.runReport({
        property,
        dateRanges: [{ startDate: `${days}daysAgo`, endDate: 'today' }],
        dimensions: [{ name: 'sessionSource' }, { name: 'sessionMedium' }],
        metrics: [
            { name: 'sessions' },
            { name: 'activeUsers' },
            { name: 'engagementRate' },
        ],
        orderBys: [{ metric: { metricName: 'sessions' }, desc: true }],
        limit: 15,
    });

    return (response.rows || []).map(r => ({
        source: r.dimensionValues[0].value,
        medium: r.dimensionValues[1].value,
        sessions: parseInt(r.metricValues[0].value),
        users: parseInt(r.metricValues[1].value),
        engagementRate: Math.round(parseFloat(r.metricValues[2].value) * 100),
    }));
}

// ─── Helpers ───────────────────────────────────────────────
function formatGADate(dateStr) {
    // GA4 returns dates as 'YYYYMMDD'
    return `${dateStr.slice(0, 4)}-${dateStr.slice(4, 6)}-${dateStr.slice(6, 8)}`;
}
