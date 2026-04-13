import { BetaAnalyticsDataClient } from '@google-analytics/data';
import { NextResponse } from 'next/server';

const propertyId = process.env.GA4_PROPERTY_ID;

function getClient() {
    return new BetaAnalyticsDataClient({
        credentials: {
            client_email: process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL,
            private_key: process.env.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        },
    });
}

// Build date range from params — supports 'today', 'yesterday', 'NdaysAgo', or 'YYYY-MM-DD'
function buildDateRange(searchParams) {
    const preset = searchParams.get('preset'); // today, yesterday, 7, 14, 30, 90, custom
    const startDate = searchParams.get('startDate');
    const endDate = searchParams.get('endDate');
    const days = parseInt(searchParams.get('days') || '30');

    if (preset === 'today') return { startDate: 'today', endDate: 'today' };
    if (preset === 'yesterday') return { startDate: 'yesterday', endDate: 'yesterday' };
    if (preset === 'custom' && startDate && endDate) return { startDate, endDate };
    return { startDate: `${days}daysAgo`, endDate: 'today' };
}

function buildComparisonRange(range) {
    // Calculate the comparison period (same duration, immediately before)
    if (range.startDate === 'today') return { startDate: 'yesterday', endDate: 'yesterday' };
    if (range.startDate === 'yesterday') return { startDate: '2daysAgo', endDate: '2daysAgo' };
    // For custom/preset ranges, use the days param approach
    return null; // handled in getOverview
}

export async function GET(request) {
    try {
        const { searchParams } = new URL(request.url);
        const type = searchParams.get('type') || 'overview';

        if (!propertyId) {
            return NextResponse.json({ error: 'GA4_PROPERTY_ID not configured. Add environment variables in Vercel Dashboard → Settings → Environment Variables.' }, { status: 500 });
        }

        const client = getClient();
        const property = `properties/${propertyId}`;
        const dateRange = buildDateRange(searchParams);

        switch (type) {
            case 'overview': return NextResponse.json(await getOverview(client, property, searchParams, dateRange));
            case 'realtime': return NextResponse.json(await getRealtime(client, property));
            case 'daily_users': return NextResponse.json(await getDailyUsers(client, property, dateRange));
            case 'demographics': return NextResponse.json(await getDemographics(client, property, dateRange));
            case 'devices': return NextResponse.json(await getDevices(client, property, dateRange));
            case 'top_screens': return NextResponse.json(await getTopScreens(client, property, dateRange));
            case 'events': return NextResponse.json(await getEvents(client, property, dateRange));
            case 'retention': return NextResponse.json(await getRetention(client, property, dateRange));
            case 'traffic_sources': return NextResponse.json(await getTrafficSources(client, property, dateRange));
            case 'hourly': return NextResponse.json(await getHourlyBreakdown(client, property, dateRange));
            case 'user_acquisition': return NextResponse.json(await getUserAcquisition(client, property, dateRange));
            case 'app_versions': return NextResponse.json(await getAppVersions(client, property, dateRange));
            case 'crash_free': return NextResponse.json(await getCrashFree(client, property, dateRange));
            default: return NextResponse.json({ error: `Unknown type: ${type}` }, { status: 400 });
        }
    } catch (error) {
        console.error('GA4 API Error:', error);
        return NextResponse.json({
            error: error.message || 'Failed to fetch GA4 data',
            details: error.details || null,
        }, { status: 500 });
    }
}

// ─── Overview ───────────────────────────────────────────────
async function getOverview(client, property, searchParams, dateRange) {
    const days = parseInt(searchParams.get('days') || '30');
    const prevRange = { startDate: `${days * 2}daysAgo`, endDate: `${days + 1}daysAgo` };

    const [response] = await client.runReport({
        property,
        dateRanges: [dateRange, prevRange],
        metrics: [
            { name: 'activeUsers' }, { name: 'newUsers' }, { name: 'sessions' },
            { name: 'screenPageViews' }, { name: 'averageSessionDuration' },
            { name: 'engagementRate' }, { name: 'sessionsPerUser' }, { name: 'totalUsers' },
            { name: 'engagedSessions' }, { name: 'crashFreeUsersRate' },
        ],
    });

    const current = response.rows?.[0]?.metricValues || [];
    const previous = response.rows?.[1]?.metricValues || [];
    const gv = (i, a) => parseFloat(a[i]?.value || '0');
    const pctChange = (i) => {
        const c = gv(i, current), p = gv(i, previous);
        if (p === 0) return c > 0 ? 100 : 0;
        return Math.round(((c - p) / p) * 100);
    };

    return {
        activeUsers: gv(0, current), newUsers: gv(1, current), sessions: gv(2, current),
        screenPageViews: gv(3, current), avgSessionDuration: Math.round(gv(4, current)),
        engagementRate: Math.round(gv(5, current) * 100),
        sessionsPerUser: Math.round(gv(6, current) * 100) / 100,
        totalUsers: gv(7, current), engagedSessions: gv(8, current),
        crashFreeRate: Math.round(gv(9, current) * 10000) / 100,
        changes: {
            activeUsers: pctChange(0), newUsers: pctChange(1),
            sessions: pctChange(2), screenPageViews: pctChange(3),
        },
    };
}

// ─── Realtime ───────────────────────────────────────────────
async function getRealtime(client, property) {
    const [total] = await client.runRealtimeReport({ property, metrics: [{ name: 'activeUsers' }] });
    const [byCountry] = await client.runRealtimeReport({ property, dimensions: [{ name: 'country' }], metrics: [{ name: 'activeUsers' }] });
    const [byDevice] = await client.runRealtimeReport({ property, dimensions: [{ name: 'deviceCategory' }], metrics: [{ name: 'activeUsers' }] });
    const [byScreen] = await client.runRealtimeReport({ property, dimensions: [{ name: 'unifiedScreenName' }], metrics: [{ name: 'activeUsers' }] });

    return {
        activeUsers: parseInt(total.rows?.[0]?.metricValues?.[0]?.value || '0'),
        byCountry: (byCountry.rows || []).map(r => ({ country: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value) })).sort((a, b) => b.users - a.users).slice(0, 10),
        byDevice: (byDevice.rows || []).map(r => ({ device: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value) })),
        byScreen: (byScreen.rows || []).map(r => ({ screen: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value) })).sort((a, b) => b.users - a.users).slice(0, 8),
    };
}

// ─── Daily Users ────────────────────────────────────────────
async function getDailyUsers(client, property, dateRange) {
    const [response] = await client.runReport({
        property, dateRanges: [dateRange],
        dimensions: [{ name: 'date' }],
        metrics: [{ name: 'activeUsers' }, { name: 'newUsers' }, { name: 'sessions' }],
        orderBys: [{ dimension: { dimensionName: 'date', orderType: 'ALPHANUMERIC' } }],
    });
    return (response.rows || []).map(r => ({
        date: formatGADate(r.dimensionValues[0].value),
        activeUsers: parseInt(r.metricValues[0].value),
        newUsers: parseInt(r.metricValues[1].value),
        sessions: parseInt(r.metricValues[2].value),
    }));
}

// ─── Demographics ───────────────────────────────────────────
async function getDemographics(client, property, dateRange) {
    const [byCountry] = await client.runReport({ property, dateRanges: [dateRange], dimensions: [{ name: 'country' }], metrics: [{ name: 'activeUsers' }, { name: 'sessions' }], orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }], limit: 15 });
    const [byCity] = await client.runReport({ property, dateRanges: [dateRange], dimensions: [{ name: 'city' }], metrics: [{ name: 'activeUsers' }], orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }], limit: 15 });
    const [byLanguage] = await client.runReport({ property, dateRanges: [dateRange], dimensions: [{ name: 'language' }], metrics: [{ name: 'activeUsers' }], orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }], limit: 10 });

    return {
        countries: (byCountry.rows || []).map(r => ({ country: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value), sessions: parseInt(r.metricValues[1].value) })),
        cities: (byCity.rows || []).map(r => ({ city: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value) })),
        languages: (byLanguage.rows || []).map(r => ({ language: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value) })),
    };
}

// ─── Device Breakdown ───────────────────────────────────────
async function getDevices(client, property, dateRange) {
    const [byCategory] = await client.runReport({ property, dateRanges: [dateRange], dimensions: [{ name: 'deviceCategory' }], metrics: [{ name: 'activeUsers' }, { name: 'sessions' }] });
    const [byOS] = await client.runReport({ property, dateRanges: [dateRange], dimensions: [{ name: 'operatingSystem' }], metrics: [{ name: 'activeUsers' }], orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }], limit: 10 });
    const [byBrand] = await client.runReport({ property, dateRanges: [dateRange], dimensions: [{ name: 'mobileDeviceBranding' }], metrics: [{ name: 'activeUsers' }], orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }], limit: 10 });
    const [byModel] = await client.runReport({ property, dateRanges: [dateRange], dimensions: [{ name: 'mobileDeviceModel' }], metrics: [{ name: 'activeUsers' }], orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }], limit: 10 });
    const [byRes] = await client.runReport({ property, dateRanges: [dateRange], dimensions: [{ name: 'screenResolution' }], metrics: [{ name: 'activeUsers' }], orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }], limit: 10 });

    return {
        categories: (byCategory.rows || []).map(r => ({ device: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value), sessions: parseInt(r.metricValues[1].value) })),
        operatingSystems: (byOS.rows || []).map(r => ({ os: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value) })),
        brands: (byBrand.rows || []).map(r => ({ brand: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value) })),
        models: (byModel.rows || []).map(r => ({ model: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value) })),
        resolutions: (byRes.rows || []).map(r => ({ resolution: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value) })),
    };
}

// ─── Top Screens ────────────────────────────────────────────
async function getTopScreens(client, property, dateRange) {
    const [response] = await client.runReport({
        property, dateRanges: [dateRange],
        dimensions: [{ name: 'unifiedScreenName' }],
        metrics: [{ name: 'screenPageViews' }, { name: 'activeUsers' }, { name: 'averageSessionDuration' }],
        orderBys: [{ metric: { metricName: 'screenPageViews' }, desc: true }], limit: 20,
    });
    return (response.rows || []).map(r => ({ screen: r.dimensionValues[0].value, views: parseInt(r.metricValues[0].value), users: parseInt(r.metricValues[1].value), avgDuration: Math.round(parseFloat(r.metricValues[2].value)) }));
}

// ─── Events ─────────────────────────────────────────────────
async function getEvents(client, property, dateRange) {
    const [response] = await client.runReport({
        property, dateRanges: [dateRange],
        dimensions: [{ name: 'eventName' }],
        metrics: [{ name: 'eventCount' }, { name: 'totalUsers' }, { name: 'eventCountPerUser' }],
        orderBys: [{ metric: { metricName: 'eventCount' }, desc: true }], limit: 30,
    });
    return (response.rows || []).map(r => ({ event: r.dimensionValues[0].value, count: parseInt(r.metricValues[0].value), users: parseInt(r.metricValues[1].value), perUser: Math.round(parseFloat(r.metricValues[2].value) * 100) / 100 }));
}

// ─── Retention ──────────────────────────────────────────────
async function getRetention(client, property, dateRange) {
    const [response] = await client.runReport({
        property, dateRanges: [dateRange],
        dimensions: [{ name: 'newVsReturning' }],
        metrics: [{ name: 'activeUsers' }, { name: 'sessions' }, { name: 'engagementRate' }, { name: 'averageSessionDuration' }],
    });
    const result = {};
    (response.rows || []).forEach(r => {
        result[r.dimensionValues[0].value] = {
            users: parseInt(r.metricValues[0].value), sessions: parseInt(r.metricValues[1].value),
            engagementRate: Math.round(parseFloat(r.metricValues[2].value) * 100),
            avgDuration: Math.round(parseFloat(r.metricValues[3].value)),
        };
    });
    return result;
}

// ─── Traffic Sources ────────────────────────────────────────
async function getTrafficSources(client, property, dateRange) {
    const [response] = await client.runReport({
        property, dateRanges: [dateRange],
        dimensions: [{ name: 'sessionSource' }, { name: 'sessionMedium' }],
        metrics: [{ name: 'sessions' }, { name: 'activeUsers' }, { name: 'engagementRate' }],
        orderBys: [{ metric: { metricName: 'sessions' }, desc: true }], limit: 15,
    });
    return (response.rows || []).map(r => ({ source: r.dimensionValues[0].value, medium: r.dimensionValues[1].value, sessions: parseInt(r.metricValues[0].value), users: parseInt(r.metricValues[1].value), engagementRate: Math.round(parseFloat(r.metricValues[2].value) * 100) }));
}

// ─── NEW: Hourly Breakdown ──────────────────────────────────
async function getHourlyBreakdown(client, property, dateRange) {
    const [response] = await client.runReport({
        property, dateRanges: [dateRange],
        dimensions: [{ name: 'hour' }],
        metrics: [{ name: 'activeUsers' }, { name: 'sessions' }],
        orderBys: [{ dimension: { dimensionName: 'hour', orderType: 'ALPHANUMERIC' } }],
    });
    return (response.rows || []).map(r => ({ hour: parseInt(r.dimensionValues[0].value), users: parseInt(r.metricValues[0].value), sessions: parseInt(r.metricValues[1].value) }));
}

// ─── NEW: User Acquisition (first visit source) ─────────────
async function getUserAcquisition(client, property, dateRange) {
    const [response] = await client.runReport({
        property, dateRanges: [dateRange],
        dimensions: [{ name: 'firstUserSource' }, { name: 'firstUserMedium' }],
        metrics: [{ name: 'newUsers' }, { name: 'sessions' }, { name: 'engagementRate' }],
        orderBys: [{ metric: { metricName: 'newUsers' }, desc: true }], limit: 15,
    });
    return (response.rows || []).map(r => ({ source: r.dimensionValues[0].value, medium: r.dimensionValues[1].value, newUsers: parseInt(r.metricValues[0].value), sessions: parseInt(r.metricValues[1].value), engagementRate: Math.round(parseFloat(r.metricValues[2].value) * 100) }));
}

// ─── NEW: App Versions ──────────────────────────────────────
async function getAppVersions(client, property, dateRange) {
    const [response] = await client.runReport({
        property, dateRanges: [dateRange],
        dimensions: [{ name: 'appVersion' }],
        metrics: [{ name: 'activeUsers' }, { name: 'sessions' }, { name: 'crashFreeUsersRate' }],
        orderBys: [{ metric: { metricName: 'activeUsers' }, desc: true }], limit: 10,
    });
    return (response.rows || []).map(r => ({ version: r.dimensionValues[0].value, users: parseInt(r.metricValues[0].value), sessions: parseInt(r.metricValues[1].value), crashFreeRate: Math.round(parseFloat(r.metricValues[2].value || '0') * 10000) / 100 }));
}

// ─── NEW: Crash-free rate (stubbed - may need firebase crashlytics) ──
async function getCrashFree(client, property, dateRange) {
    const [response] = await client.runReport({
        property, dateRanges: [dateRange],
        dimensions: [{ name: 'date' }],
        metrics: [{ name: 'crashFreeUsersRate' }, { name: 'activeUsers' }],
        orderBys: [{ dimension: { dimensionName: 'date', orderType: 'ALPHANUMERIC' } }],
    });
    return (response.rows || []).map(r => ({ date: formatGADate(r.dimensionValues[0].value), crashFreeRate: Math.round(parseFloat(r.metricValues[0].value || '0') * 10000) / 100, users: parseInt(r.metricValues[1].value) }));
}

function formatGADate(dateStr) {
    return `${dateStr.slice(0, 4)}-${dateStr.slice(4, 6)}-${dateStr.slice(6, 8)}`;
}
