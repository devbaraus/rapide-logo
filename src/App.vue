<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'

type IconItem = {
  name: string
  label: string
}

type IconSetItem = {
  prefix: string
  name: string
  total: number
  category: string
}

type IconSetInfo = {
  name?: string
  total?: number
  category?: string
}

type IconSetResponse = {
  uncategorized?: string[]
  categories?: Record<string, string[]>
  icons?: string[]
  aliases?: Record<string, unknown>
  info?: IconSetInfo
}

type ZipPart = ArrayBuffer

type ShadowSize = 'none' | 'sm' | 'md' | 'lg' | 'xl'
type BackgroundMode = 'solid' | 'gradient'
type Tab = 'icon' | 'background'
type IconBrowserMode = 'sets' | 'set-icons' | 'search'

const defaultIcons: IconItem[] = [
  { name: 'ph:chats-bold', label: 'Chats' },
  { name: 'ph:lightning-bold', label: 'Lightning' },
  { name: 'ph:rocket-launch-bold', label: 'Rocket' },
  { name: 'ph:sparkle-bold', label: 'Sparkle' },
  { name: 'ph:code-bold', label: 'Code' },
  { name: 'ph:shopping-bag-bold', label: 'Shop' },
  { name: 'ph:waveform-bold', label: 'Wave' },
  { name: 'ph:currency-circle-dollar-bold', label: 'Money' },
  { name: 'ph:calendar-check-bold', label: 'Calendar' },
  { name: 'ph:heart-bold', label: 'Heart' },
  { name: 'ph:chart-line-up-bold', label: 'Growth' },
  { name: 'ph:star-four-bold', label: 'Star' },
]

const presets = [
  { background: '#1d5dfb', icon: '#ffffff', accent: '#1d5dfb' },
  { background: '#0f172a', icon: '#ffffff', accent: '#111827' },
  { background: '#f9d84a', icon: '#1f2937', accent: '#f6c443' },
  { background: '#f37abd', icon: '#271123', accent: '#f37abd' },
  { background: '#9df391', icon: '#14341a', accent: '#9df391' },
  { background: '#a7f3f0', icon: '#0f3f48', accent: '#56d4dc' },
]

const swatches = [
  '#1d5dfb',
  '#0f172a',
  '#ffffff',
  '#f43f5e',
  '#fb7185',
  '#f97316',
  '#fde68a',
  '#d9f99d',
  '#4ade80',
  '#67e8f9',
  '#38bdf8',
  '#818cf8',
  '#c084fc',
  '#e879f9',
]

const shadowOptions: { label: string; value: ShadowSize }[] = [
  { label: 'None', value: 'none' },
  { label: 'SM', value: 'sm' },
  { label: 'MD', value: 'md' },
  { label: 'LG', value: 'lg' },
  { label: 'XL', value: 'xl' },
]

const initialIcon = defaultIcons[0]!
const activeTab = ref<Tab>('icon')
const icons = ref<IconItem[]>(defaultIcons)
const iconSetIcons = ref<IconItem[]>([])
const iconSets = ref<IconSetItem[]>([])
const selectedIconSet = ref<IconSetItem | null>(null)
const selectedIcon = ref<IconItem>(initialIcon)
const searchQuery = ref('')
const iconSetSearchQuery = ref('')
const searchStatus = ref('Ready')
const iconBrowserMode = ref<IconBrowserMode>('sets')
const iconScrollTop = ref(0)
const selectedIconSvg = ref('')
const isSearching = ref(false)
const isLoadingSets = ref(false)
const isLoadingSetIcons = ref(false)
const isExporting = ref(false)
let searchTimeout = 0

const iconGridColumns = 5
const iconRowHeight = 50
const iconViewportHeight = 302
const iconBufferRows = 3

const settings = reactive({
  iconColor: '#ffffff',
  iconSize: 226,
  iconOffsetX: 0,
  iconOffsetY: 0,
  rotation: 0,
  backgroundMode: 'solid' as BackgroundMode,
  backgroundColor: '#1d5dfb',
  gradientStart: '#1d5dfb',
  gradientEnd: '#7c3aed',
  radius: 88,
  padding: 0,
  shadow: 'none' as ShadowSize,
  canvasSize: 512,
  pngSize: 1024,
})

const selectedIconName = computed(() => selectedIcon.value.name)

const logoStyle = computed(() => {
  return buildLogoStyle(settings.canvasSize, settings.padding, settings.radius)
})

const miniLogoStyle = computed(() => {
  const scale = 140 / settings.canvasSize
  return buildLogoStyle(
    140,
    Math.round(settings.padding * scale),
    Math.round(settings.radius * scale),
  )
})

const iconStyle = computed(() => buildIconStyle(1))
const miniIconStyle = computed(() => buildIconStyle(140 / settings.canvasSize))

function buildLogoStyle(size: number, padding: number, radius: number) {
  const background =
    settings.backgroundMode === 'gradient'
      ? `linear-gradient(135deg, ${settings.gradientStart}, ${settings.gradientEnd})`
      : settings.backgroundColor

  return {
    width: `${size}px`,
    height: `${size}px`,
    padding: `${padding}px`,
    borderRadius: `${radius}px`,
    background,
    boxShadow: shadowCss(settings.shadow),
  }
}

function buildIconStyle(scale: number) {
  return {
    width: `${Math.round(settings.iconSize * scale)}px`,
    height: `${Math.round(settings.iconSize * scale)}px`,
    transform: `translate(${Math.round(settings.iconOffsetX * scale)}px, ${Math.round(settings.iconOffsetY * scale)}px) rotate(${settings.rotation}deg)`,
    color: settings.iconColor,
  }
}

const canUsePng = computed(() => selectedIconSvg.value.length > 0)
const iconSetCount = computed(() =>
  iconSets.value.reduce((total, iconSet) => total + iconSet.total, 0),
)
const displayedIcons = computed(() => {
  if (iconBrowserMode.value !== 'set-icons') {
    return icons.value
  }

  const query = iconSetSearchQuery.value.trim().toLowerCase()

  if (!query) {
    return iconSetIcons.value
  }

  return iconSetIcons.value.filter((icon) => {
    return icon.name.toLowerCase().includes(query) || icon.label.toLowerCase().includes(query)
  })
})
const totalIconRows = computed(() => Math.ceil(displayedIcons.value.length / iconGridColumns))
const visibleStartRow = computed(() =>
  Math.max(0, Math.floor(iconScrollTop.value / iconRowHeight) - iconBufferRows),
)
const visibleEndRow = computed(() =>
  Math.min(
    totalIconRows.value,
    visibleStartRow.value + Math.ceil(iconViewportHeight / iconRowHeight) + iconBufferRows * 2,
  ),
)
const visibleIcons = computed(() =>
  displayedIcons.value.slice(
    visibleStartRow.value * iconGridColumns,
    visibleEndRow.value * iconGridColumns,
  ),
)
const iconTopSpacer = computed(() => `${visibleStartRow.value * iconRowHeight}px`)
const iconBottomSpacer = computed(
  () => `${Math.max(0, totalIconRows.value - visibleEndRow.value) * iconRowHeight}px`,
)
const iconPanelTitle = computed(() => {
  if (iconBrowserMode.value === 'search') {
    return 'Search results'
  }

  if (selectedIconSet.value) {
    const visibleCount = displayedIcons.value.length.toLocaleString()
    return `${selectedIconSet.value.name} (${visibleCount})`
  }

  return 'Icon sets'
})
const isIconBrowserLoading = computed(
  () => isSearching.value || isLoadingSets.value || isLoadingSetIcons.value,
)

function iconLabel(name: string) {
  const [, rawName = name] = name.split(':')
  return rawName.replace(/-/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function iconApiUrl(iconName: string, color = settings.iconColor) {
  const [prefix, name] = iconName.split(':')
  return `https://api.iconify.design/${prefix}/${name}.svg?color=${encodeURIComponent(color)}`
}

function shadowCss(size: ShadowSize) {
  return {
    none: 'none',
    sm: '0 10px 24px rgba(15, 23, 42, 0.14)',
    md: '0 18px 38px rgba(15, 23, 42, 0.18)',
    lg: '0 28px 58px rgba(15, 23, 42, 0.22)',
    xl: '0 42px 90px rgba(15, 23, 42, 0.28)',
  }[size]
}

function choosePreset(preset: (typeof presets)[number]) {
  settings.backgroundColor = preset.background
  settings.gradientStart = preset.background
  settings.gradientEnd = preset.accent
  settings.iconColor = preset.icon
}

function chooseIcon(icon: IconItem) {
  selectedIcon.value = icon
}

function applySwatch(color: string, target: 'background' | 'icon') {
  if (target === 'icon') {
    settings.iconColor = color
    return
  }

  settings.backgroundColor = color
  settings.gradientStart = color
}

function resetIconScroll() {
  iconScrollTop.value = 0
}

function onIconGridScroll(event: Event) {
  iconScrollTop.value = (event.currentTarget as HTMLElement).scrollTop
}

function buildIconItems(prefix: string, names: string[]) {
  return names.map((name) => ({
    name: `${prefix}:${name}`,
    label: iconLabel(`${prefix}:${name}`),
  }))
}

function showIconSets() {
  selectedIconSet.value = null
  iconBrowserMode.value = 'sets'
  icons.value = []
  iconSetIcons.value = []
  iconSetSearchQuery.value = ''
  resetIconScroll()

  if (!iconSets.value.length) {
    loadIconSets()
  } else {
    searchStatus.value = `${iconSets.value.length} icon sets, ${iconSetCount.value.toLocaleString()} icons`
  }
}

async function loadIconSets() {
  isLoadingSets.value = true
  searchStatus.value = 'Loading icon sets...'

  try {
    const response = await fetch('https://api.iconify.design/collections')

    if (!response.ok) {
      throw new Error('Icon sets failed to load')
    }

    const data = (await response.json()) as Record<string, IconSetInfo>
    iconSets.value = Object.entries(data)
      .map(([prefix, info]) => ({
        prefix,
        name: info.name || prefix,
        total: info.total || 0,
        category: info.category || 'General',
      }))
      .sort((a, b) => b.total - a.total || a.name.localeCompare(b.name))

    searchStatus.value = `${iconSets.value.length} icon sets, ${iconSetCount.value.toLocaleString()} icons`
  } catch {
    iconSets.value = [
      { prefix: 'ph', name: 'Phosphor', total: defaultIcons.length, category: 'General' },
    ]
    searchStatus.value = 'Icon sets unavailable'
  } finally {
    isLoadingSets.value = false
  }
}

async function chooseIconSet(iconSet: IconSetItem) {
  selectedIconSet.value = iconSet
  iconBrowserMode.value = 'set-icons'
  icons.value = []
  iconSetIcons.value = []
  iconSetSearchQuery.value = ''
  resetIconScroll()
  isLoadingSetIcons.value = true
  searchStatus.value = `Loading ${iconSet.name}...`

  try {
    const response = await fetch(
      `https://api.iconify.design/collection?prefix=${encodeURIComponent(iconSet.prefix)}`,
    )

    if (!response.ok) {
      throw new Error('Icon set failed to load')
    }

    const data = (await response.json()) as IconSetResponse
    const iconNames = [
      ...(data.uncategorized ?? []),
      ...Object.values(data.categories ?? {}).flat(),
      ...Object.keys(data.aliases ?? {}),
      ...(data.icons ?? []),
    ]
    const uniqueNames = [...new Set(iconNames)].sort((a, b) => a.localeCompare(b))

    iconSetIcons.value = uniqueNames.length ? buildIconItems(iconSet.prefix, uniqueNames) : []
    icons.value = iconSetIcons.value
    searchStatus.value = uniqueNames.length
      ? `${uniqueNames.length.toLocaleString()} icons in ${iconSet.name}`
      : `No icons found in ${iconSet.name}`
  } catch {
    iconSetIcons.value = []
    icons.value = []
    searchStatus.value = `Could not load ${iconSet.name}`
  } finally {
    isLoadingSetIcons.value = false
  }
}

async function searchIcons() {
  const query = searchQuery.value.trim()

  if (!query) {
    showIconSets()
    return
  }

  isSearching.value = true
  iconBrowserMode.value = 'search'
  selectedIconSet.value = null
  iconSetIcons.value = []
  iconSetSearchQuery.value = ''
  resetIconScroll()
  searchStatus.value = 'Searching Iconify...'

  try {
    const response = await fetch(
      `https://api.iconify.design/search?query=${encodeURIComponent(query)}&limit=250`,
    )

    if (!response.ok) {
      throw new Error('Icon search failed')
    }

    const data = (await response.json()) as { icons?: string[] }
    const results =
      data.icons?.map((name) => ({
        name,
        label: iconLabel(name),
      })) ?? []

    icons.value = results
    searchStatus.value = results.length ? `${results.length} icons found` : 'No matching icons'
  } catch {
    icons.value = []
    searchStatus.value = 'Iconify search unavailable'
  } finally {
    isSearching.value = false
  }
}

function queueSearch() {
  window.clearTimeout(searchTimeout)
  searchTimeout = window.setTimeout(searchIcons, 320)
}

async function loadSelectedIcon() {
  try {
    const response = await fetch(iconApiUrl(selectedIcon.value.name, settings.iconColor))

    if (!response.ok) {
      throw new Error('Icon failed to load')
    }

    selectedIconSvg.value = await response.text()
  } catch {
    selectedIconSvg.value = ''
  }
}

function buildLogoSvg(outputSize = settings.canvasSize) {
  const scale = outputSize / settings.canvasSize
  const size = outputSize
  const padding = settings.padding * scale
  const radius = settings.radius * scale
  const innerSize = Math.min(settings.iconSize * scale, size - padding * 2)
  const x = (size - innerSize) / 2 + settings.iconOffsetX * scale
  const y = (size - innerSize) / 2 + settings.iconOffsetY * scale
  const rotationCenterX = size / 2 + settings.iconOffsetX * scale
  const rotationCenterY = size / 2 + settings.iconOffsetY * scale
  const background =
    settings.backgroundMode === 'gradient'
      ? 'url(#logoGradient)'
      : escapeAttribute(settings.backgroundColor)
  const defs =
    settings.backgroundMode === 'gradient'
      ? `<defs><linearGradient id="logoGradient" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="${escapeAttribute(
          settings.gradientStart,
        )}"/><stop offset="100%" stop-color="${escapeAttribute(settings.gradientEnd)}"/></linearGradient></defs>`
      : ''
  const icon = normalizeIconSvg(selectedIconSvg.value, innerSize, x, y)
  const shadow = settings.shadow === 'none' ? '' : shadowFilter(scale)
  const filter = settings.shadow === 'none' ? '' : ' filter="url(#shadow)"'
  const rotation =
    settings.rotation === 0
      ? ''
      : ` transform="rotate(${settings.rotation} ${rotationCenterX} ${rotationCenterY})"`

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
${defs}${shadow}
<rect width="${size}" height="${size}" rx="${radius}" fill="${background}"${filter}/>
<g${rotation}>${icon}</g>
</svg>`
}

function normalizeIconSvg(svg: string, size: number, x: number, y: number) {
  if (!svg) {
    return ''
  }

  const openingTag = svg.match(/<svg\b([^>]*)>/)
  const rawAttributes = openingTag?.[1] ?? ' viewBox="0 0 24 24"'
  const attributes = rawAttributes
    .replace(/\s(?:x|y|width|height)="[^"]*"/g, '')
    .replace(/\sxmlns="[^"]*"/g, '')
  const content = svg.replace(/<svg\b[^>]*>/, '').replace(/<\/svg>\s*$/, '')

  return `<svg x="${x}" y="${y}" width="${size}" height="${size}"${attributes}>${content}</svg>`
}

function shadowFilter(scale = 1) {
  return `<defs><filter id="shadow" x="-25%" y="-25%" width="150%" height="150%"><feDropShadow dx="0" dy="${24 * scale}" stdDeviation="${24 * scale}" flood-color="#0f172a" flood-opacity="0.24"/></filter></defs>`
}

function escapeAttribute(value: string) {
  return value.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;')
}

function downloadFile(filename: string, blob: Blob) {
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}

async function renderPngBlob(size: number) {
  await loadSelectedIcon()
  const svg = buildLogoSvg(size)
  const svgUrl = URL.createObjectURL(new Blob([svg], { type: 'image/svg+xml' }))

  try {
    const image = new Image()

    await new Promise<void>((resolve, reject) => {
      image.onload = () => resolve()
      image.onerror = reject
      image.src = svgUrl
    })

    const canvas = document.createElement('canvas')
    canvas.width = size
    canvas.height = size
    const context = canvas.getContext('2d')

    if (!context) {
      throw new Error('Canvas unavailable')
    }

    context.drawImage(image, 0, 0, size, size)

    return await new Promise<Blob>((resolve, reject) => {
      canvas.toBlob((blob) => {
        if (blob) {
          resolve(blob)
          return
        }

        reject(new Error('PNG export failed'))
      }, 'image/png')
    })
  } finally {
    URL.revokeObjectURL(svgUrl)
  }
}

async function buildIcoBlob(sizes: number[]) {
  const pngBuffers = await Promise.all(
    sizes.map(async (size) => {
      const blob = await renderPngBlob(size)
      return {
        size,
        buffer: await blob.arrayBuffer(),
      }
    }),
  )
  const headerSize = 6
  const directorySize = pngBuffers.length * 16
  let imageOffset = headerSize + directorySize
  const directory = new ArrayBuffer(headerSize + directorySize)
  const view = new DataView(directory)

  view.setUint16(0, 0, true)
  view.setUint16(2, 1, true)
  view.setUint16(4, pngBuffers.length, true)

  pngBuffers.forEach(({ size, buffer }, index) => {
    const entryOffset = headerSize + index * 16
    view.setUint8(entryOffset, size >= 256 ? 0 : size)
    view.setUint8(entryOffset + 1, size >= 256 ? 0 : size)
    view.setUint8(entryOffset + 2, 0)
    view.setUint8(entryOffset + 3, 0)
    view.setUint16(entryOffset + 4, 1, true)
    view.setUint16(entryOffset + 6, 32, true)
    view.setUint32(entryOffset + 8, buffer.byteLength, true)
    view.setUint32(entryOffset + 12, imageOffset, true)
    imageOffset += buffer.byteLength
  })

  return new Blob([directory, ...pngBuffers.map(({ buffer }) => buffer)], {
    type: 'image/x-icon',
  })
}

function crc32(buffer: ArrayBuffer) {
  const table = crc32Table()
  const bytes = new Uint8Array(buffer)
  let crc = 0xffffffff

  for (const byte of bytes) {
    crc = (crc >>> 8) ^ table[(crc ^ byte) & 0xff]!
  }

  return (crc ^ 0xffffffff) >>> 0
}

function crc32Table() {
  const table = new Uint32Array(256)

  for (let index = 0; index < 256; index += 1) {
    let value = index

    for (let bit = 0; bit < 8; bit += 1) {
      value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1
    }

    table[index] = value >>> 0
  }

  return table
}

function writeUint16(bytes: number[], value: number) {
  bytes.push(value & 0xff, (value >>> 8) & 0xff)
}

function writeUint32(bytes: number[], value: number) {
  bytes.push(value & 0xff, (value >>> 8) & 0xff, (value >>> 16) & 0xff, (value >>> 24) & 0xff)
}

function toArrayBuffer(bytes: Uint8Array) {
  const copy = new Uint8Array(bytes.byteLength)
  copy.set(bytes)
  return copy.buffer
}

async function buildZipBlob(files: { name: string; blob: Blob }[]) {
  const encoder = new TextEncoder()
  const localParts: ZipPart[] = []
  const centralParts: ZipPart[] = []
  let offset = 0

  for (const file of files) {
    const nameBytes = encoder.encode(file.name)
    const buffer = await file.blob.arrayBuffer()
    const checksum = crc32(buffer)
    const localHeader: number[] = []

    writeUint32(localHeader, 0x04034b50)
    writeUint16(localHeader, 20)
    writeUint16(localHeader, 0)
    writeUint16(localHeader, 0)
    writeUint16(localHeader, 0)
    writeUint16(localHeader, 0)
    writeUint32(localHeader, checksum)
    writeUint32(localHeader, buffer.byteLength)
    writeUint32(localHeader, buffer.byteLength)
    writeUint16(localHeader, nameBytes.byteLength)
    writeUint16(localHeader, 0)

    localParts.push(toArrayBuffer(new Uint8Array(localHeader)), toArrayBuffer(nameBytes), buffer)

    const centralHeader: number[] = []
    writeUint32(centralHeader, 0x02014b50)
    writeUint16(centralHeader, 20)
    writeUint16(centralHeader, 20)
    writeUint16(centralHeader, 0)
    writeUint16(centralHeader, 0)
    writeUint16(centralHeader, 0)
    writeUint16(centralHeader, 0)
    writeUint32(centralHeader, checksum)
    writeUint32(centralHeader, buffer.byteLength)
    writeUint32(centralHeader, buffer.byteLength)
    writeUint16(centralHeader, nameBytes.byteLength)
    writeUint16(centralHeader, 0)
    writeUint16(centralHeader, 0)
    writeUint16(centralHeader, 0)
    writeUint16(centralHeader, 0)
    writeUint32(centralHeader, 0)
    writeUint32(centralHeader, offset)

    centralParts.push(toArrayBuffer(new Uint8Array(centralHeader)), toArrayBuffer(nameBytes))
    offset += localHeader.length + nameBytes.byteLength + buffer.byteLength
  }

  const centralDirectorySize = centralParts.reduce((size, part) => {
    return size + part.byteLength
  }, 0)
  const endHeader: number[] = []

  writeUint32(endHeader, 0x06054b50)
  writeUint16(endHeader, 0)
  writeUint16(endHeader, 0)
  writeUint16(endHeader, files.length)
  writeUint16(endHeader, files.length)
  writeUint32(endHeader, centralDirectorySize)
  writeUint32(endHeader, offset)
  writeUint16(endHeader, 0)

  return new Blob([...localParts, ...centralParts, toArrayBuffer(new Uint8Array(endHeader))], {
    type: 'application/zip',
  })
}

async function downloadSvg() {
  await loadSelectedIcon()
  const svg = buildLogoSvg()
  downloadFile('rapide-logo.svg', new Blob([svg], { type: 'image/svg+xml' }))
}

async function downloadPng() {
  isExporting.value = true

  try {
    const blob = await renderPngBlob(settings.pngSize)
    downloadFile(`rapide-logo-${settings.pngSize}.png`, blob)
  } catch {
    // The disabled state is enough feedback for this compact export panel.
  } finally {
    isExporting.value = false
  }
}

async function downloadFaviconAssets() {
  isExporting.value = true

  try {
    const faviconIco = await buildIcoBlob([16, 32, 48])
    const faviconSvg = new Blob([buildLogoSvg(512)], { type: 'image/svg+xml' })
    const appleTouchIcon = await renderPngBlob(180)

    downloadFile('favicon.ico', faviconIco)
    downloadFile('favicon.svg', faviconSvg)
    downloadFile('apple-touch-icon.png', appleTouchIcon)
  } finally {
    isExporting.value = false
  }
}

async function downloadPwaAssets() {
  isExporting.value = true

  try {
    const icon192 = await renderPngBlob(192)
    const icon512 = await renderPngBlob(512)
    const maskable192 = await renderPngBlob(192)
    const maskable512 = await renderPngBlob(512)
    const faviconIco = await buildIcoBlob([16, 32, 48])
    const faviconSvg = new Blob([buildLogoSvg(512)], { type: 'image/svg+xml' })
    const appleTouchIcon = await renderPngBlob(180)
    const manifest = {
      name: 'Rapide Logo',
      short_name: 'Rapide',
      icons: [
        { src: '/favicon.svg', sizes: 'any', type: 'image/svg+xml' },
        { src: '/pwa-192x192.png', sizes: '192x192', type: 'image/png' },
        { src: '/pwa-512x512.png', sizes: '512x512', type: 'image/png' },
        {
          src: '/maskable-192x192.png',
          sizes: '192x192',
          type: 'image/png',
          purpose: 'maskable',
        },
        {
          src: '/maskable-512x512.png',
          sizes: '512x512',
          type: 'image/png',
          purpose: 'maskable',
        },
      ],
    }

    const zip = await buildZipBlob([
      { name: 'pwa-192x192.png', blob: icon192 },
      { name: 'pwa-512x512.png', blob: icon512 },
      { name: 'maskable-192x192.png', blob: maskable192 },
      { name: 'maskable-512x512.png', blob: maskable512 },
      { name: 'favicon.ico', blob: faviconIco },
      { name: 'favicon.svg', blob: faviconSvg },
      { name: 'apple-touch-icon.png', blob: appleTouchIcon },
      {
        name: 'site.webmanifest',
        blob: new Blob([JSON.stringify(manifest, null, 2)], {
          type: 'application/manifest+json',
        }),
      },
    ])

    downloadFile('pwa-assets.zip', zip)
  } finally {
    isExporting.value = false
  }
}

watch(selectedIconName, loadSelectedIcon)
watch(() => settings.iconColor, loadSelectedIcon)
watch(iconSetSearchQuery, (query) => {
  if (iconBrowserMode.value !== 'set-icons' || !selectedIconSet.value) {
    return
  }

  const trimmedQuery = query.trim()
  searchStatus.value = trimmedQuery
    ? `${displayedIcons.value.length.toLocaleString()} matches in ${selectedIconSet.value.name}`
    : `${iconSetIcons.value.length.toLocaleString()} icons in ${selectedIconSet.value.name}`
})

onMounted(() => {
  searchIcons()
  loadSelectedIcon()
})
</script>

<template>
  <main class="app-shell">
    <aside class="tool-panel">
      <div class="brand">
        <span class="brand-mark">R</span>
        <span>Rapide Logo</span>
      </div>

      <nav class="tabs" aria-label="Editor sections">
        <button :class="{ active: activeTab === 'icon' }" type="button" @click="activeTab = 'icon'">
          Icon
        </button>
        <button
          :class="{ active: activeTab === 'background' }"
          type="button"
          @click="activeTab = 'background'"
        >
          Background
        </button>
      </nav>

      <section v-if="activeTab === 'icon'" class="control-stack" aria-label="Icon controls">
        <label class="field">
          <span>Search Iconify</span>
          <input
            v-model="searchQuery"
            type="search"
            placeholder="chat, bolt, rocket"
            @input="queueSearch"
          />
        </label>

        <div class="status-line">
          <span>{{ searchStatus }}</span>
          <span v-if="isIconBrowserLoading">Loading</span>
        </div>

        <div class="browser-heading">
          <button
            v-if="iconBrowserMode === 'set-icons'"
            class="back-button"
            type="button"
            @click="showIconSets"
          >
            Back
          </button>
          <span>{{ iconPanelTitle }}</span>
        </div>

        <label v-if="iconBrowserMode === 'set-icons'" class="field compact-field">
          <span>Search this icon set</span>
          <input
            v-model="iconSetSearchQuery"
            type="search"
            placeholder="arrow, home, user"
            @input="resetIconScroll"
          />
        </label>

        <div v-if="iconBrowserMode === 'sets'" class="icon-set-list">
          <button
            v-for="iconSet in iconSets"
            :key="iconSet.prefix"
            class="icon-set-choice"
            type="button"
            @click="chooseIconSet(iconSet)"
          >
            <span class="set-prefix">{{ iconSet.prefix }}</span>
            <span class="set-detail">
              <strong>{{ iconSet.name }}</strong>
              <small>{{ iconSet.total.toLocaleString() }} icons</small>
            </span>
          </button>
        </div>

        <div
          v-else
          class="icon-grid"
          :style="{ '--icon-top-spacer': iconTopSpacer, '--icon-bottom-spacer': iconBottomSpacer }"
          @scroll="onIconGridScroll"
        >
          <div class="icon-spacer top" aria-hidden="true"></div>
          <button
            v-for="icon in visibleIcons"
            :key="icon.name"
            class="icon-choice"
            :class="{ active: icon.name === selectedIcon.name }"
            :title="icon.name"
            type="button"
            @click="chooseIcon(icon)"
          >
            <img :src="iconApiUrl(icon.name, '#111827')" :alt="icon.label" loading="lazy" />
          </button>
          <div v-if="!visibleIcons.length && !isIconBrowserLoading" class="empty-icons">
            No icons to show
          </div>
          <div class="icon-spacer bottom" aria-hidden="true"></div>
        </div>

        <label class="field">
          <span>Icon color</span>
          <input v-model="settings.iconColor" type="color" />
        </label>

        <div class="swatches">
          <button
            v-for="color in swatches"
            :key="`icon-${color}`"
            :style="{ backgroundColor: color }"
            :title="color"
            type="button"
            @click="applySwatch(color, 'icon')"
          />
        </div>

        <label class="range-field">
          <span>Size</span>
          <span class="number-control">
            <input v-model.number="settings.iconSize" min="120" max="360" type="number" />
            <strong>px</strong>
          </span>
          <input v-model.number="settings.iconSize" min="120" max="360" type="range" />
        </label>

        <label class="range-field">
          <span>Rotate</span>
          <span class="number-control">
            <input v-model.number="settings.rotation" min="-45" max="45" type="number" />
            <strong>deg</strong>
          </span>
          <input v-model.number="settings.rotation" min="-45" max="45" type="range" />
        </label>

        <label class="range-field">
          <span>Horizontal offset</span>
          <span class="number-control">
            <input v-model.number="settings.iconOffsetX" min="-160" max="160" type="number" />
            <strong>px</strong>
          </span>
          <input v-model.number="settings.iconOffsetX" min="-160" max="160" type="range" />
        </label>

        <label class="range-field">
          <span>Vertical offset</span>
          <span class="number-control">
            <input v-model.number="settings.iconOffsetY" min="-160" max="160" type="number" />
            <strong>px</strong>
          </span>
          <input v-model.number="settings.iconOffsetY" min="-160" max="160" type="range" />
        </label>
      </section>

      <section v-else class="control-stack" aria-label="Background controls">
        <div class="segmented" aria-label="Background mode">
          <button
            :class="{ active: settings.backgroundMode === 'solid' }"
            type="button"
            @click="settings.backgroundMode = 'solid'"
          >
            Solid
          </button>
          <button
            :class="{ active: settings.backgroundMode === 'gradient' }"
            type="button"
            @click="settings.backgroundMode = 'gradient'"
          >
            Gradient
          </button>
        </div>

        <label class="field">
          <span>Background</span>
          <input v-model="settings.backgroundColor" type="color" />
        </label>

        <template v-if="settings.backgroundMode === 'gradient'">
          <label class="field">
            <span>Gradient start</span>
            <input v-model="settings.gradientStart" type="color" />
          </label>
          <label class="field">
            <span>Gradient end</span>
            <input v-model="settings.gradientEnd" type="color" />
          </label>
        </template>

        <div class="swatches">
          <button
            v-for="color in swatches"
            :key="`bg-${color}`"
            :style="{ backgroundColor: color }"
            :title="color"
            type="button"
            @click="applySwatch(color, 'background')"
          />
        </div>

        <label class="range-field">
          <span>Rounded</span>
          <span class="number-control">
            <input v-model.number="settings.radius" min="0" max="128" type="number" />
            <strong>px</strong>
          </span>
          <input v-model.number="settings.radius" min="0" max="128" type="range" />
        </label>

        <label class="range-field">
          <span>Padding</span>
          <span class="number-control">
            <input v-model.number="settings.padding" min="0" max="84" type="number" />
            <strong>px</strong>
          </span>
          <input v-model.number="settings.padding" min="0" max="84" type="range" />
        </label>

        <div class="control-group">
          <span>Shadow</span>
          <div class="shadow-list">
            <button
              v-for="option in shadowOptions"
              :key="option.value"
              :class="{ active: settings.shadow === option.value }"
              type="button"
              @click="settings.shadow = option.value"
            >
              {{ option.label }}
            </button>
          </div>
        </div>
      </section>
    </aside>

    <section class="workbench" aria-label="Logo preview">
      <header class="topbar">
        <button class="icon-button" type="button" title="Reset" @click="settings.rotation = 0">
          <span>↶</span>
        </button>
        <div class="preset-strip" aria-label="Color presets">
          <span>Presets</span>
          <button
            v-for="preset in presets"
            :key="`${preset.background}-${preset.icon}`"
            class="preset"
            :style="{ backgroundColor: preset.background, color: preset.icon }"
            type="button"
            :title="preset.background"
            @click="choosePreset(preset)"
          >
            <span class="preset-glyph">⌁</span>
          </button>
        </div>
      </header>

      <div class="canvas-wrap">
        <div class="grid-floor" aria-hidden="true"></div>
        <div class="logo-frame" :style="logoStyle">
          <div
            v-if="selectedIconSvg"
            class="logo-icon"
            :style="iconStyle"
            v-html="selectedIconSvg"
          ></div>
        </div>
      </div>
    </section>

    <aside class="export-panel">
      <div>
        <p class="eyebrow">Selected icon</p>
        <h1>{{ selectedIcon.label }}</h1>
        <p class="icon-name">{{ selectedIcon.name }}</p>
      </div>

      <div class="preview-card">
        <div class="mini-logo" :style="miniLogoStyle">
          <div
            v-if="selectedIconSvg"
            class="logo-icon"
            :style="miniIconStyle"
            v-html="selectedIconSvg"
          ></div>
        </div>
      </div>

      <label class="range-field">
        <span>Canvas</span>
        <span class="number-control">
          <input
            v-model.number="settings.canvasSize"
            min="256"
            max="1024"
            step="64"
            type="number"
          />
          <strong>px</strong>
        </span>
        <input v-model.number="settings.canvasSize" min="256" max="1024" step="64" type="range" />
      </label>

      <label class="range-field">
        <span>PNG export size</span>
        <span class="number-control">
          <input v-model.number="settings.pngSize" min="64" max="2048" step="64" type="number" />
          <strong>px</strong>
        </span>
        <input v-model.number="settings.pngSize" min="64" max="2048" step="64" type="range" />
      </label>

      <div class="export-size-presets" aria-label="PNG size presets">
        <button type="button" @click="settings.pngSize = 256">256</button>
        <button type="button" @click="settings.pngSize = 512">512</button>
        <button type="button" @click="settings.pngSize = 1024">1024</button>
        <button type="button" @click="settings.pngSize = 2048">2048</button>
      </div>

      <div class="download-actions">
        <button :disabled="!canUsePng || isExporting" type="button" @click="downloadPng">
          Download PNG {{ settings.pngSize }}px
        </button>
        <button :disabled="!canUsePng" type="button" @click="downloadSvg">Download SVG</button>
        <button :disabled="!canUsePng || isExporting" type="button" @click="downloadFaviconAssets">
          Download Favicon
        </button>
        <button :disabled="!canUsePng || isExporting" type="button" @click="downloadPwaAssets">
          Download PWA ZIP
        </button>
      </div>

      <div class="meta-list">
        <div>
          <span>Source</span>
          <strong>Iconify</strong>
        </div>
        <div>
          <span>Format</span>
          <strong>Vector + PNG</strong>
        </div>
        <div>
          <span>License</span>
          <strong>Per icon set</strong>
        </div>
      </div>
    </aside>
  </main>
</template>

<style scoped>
:global(*) {
  box-sizing: border-box;
}

:global(body) {
  margin: 0;
  min-width: 320px;
  color: #24272f;
  background: #f8f9fb;
  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    'Segoe UI',
    sans-serif;
}

:global(button),
:global(input) {
  font: inherit;
}

.app-shell {
  display: grid;
  grid-template-columns: 320px minmax(420px, 1fr) 300px;
  min-height: 100vh;
  overflow: hidden;
}

.tool-panel,
.export-panel {
  z-index: 2;
  display: flex;
  flex-direction: column;
  gap: 22px;
  min-height: 100vh;
  padding: 24px;
  background: #ffffff;
  border-color: #e7eaf0;
}

.tool-panel {
  border-right: 1px solid #e7eaf0;
}

.export-panel {
  border-left: 1px solid #e7eaf0;
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 36px;
  color: #15171c;
  font-size: 18px;
  font-weight: 800;
}

.brand-mark {
  display: grid;
  width: 28px;
  height: 28px;
  place-items: center;
  color: #ffffff;
  background: #111111;
  border-radius: 7px;
  font-size: 17px;
  line-height: 1;
}

.tabs,
.segmented {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6px;
  padding: 4px;
  background: #f0f2f5;
  border-radius: 8px;
}

.tabs button,
.segmented button {
  height: 38px;
  border: 0;
  color: #5c6472;
  background: transparent;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 700;
}

.tabs button.active,
.segmented button.active {
  color: #111827;
  background: #ffffff;
  box-shadow: 0 1px 4px rgba(15, 23, 42, 0.12);
}

.control-stack {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.field,
.range-field,
.control-group {
  display: flex;
  flex-direction: column;
  gap: 9px;
  color: #555c68;
  font-size: 14px;
  font-weight: 700;
}

.field input[type='search'] {
  width: 100%;
  height: 42px;
  padding: 0 13px;
  color: #111827;
  background: #f8fafc;
  border: 1px solid #dbe1ea;
  border-radius: 8px;
  outline: 0;
}

.field input[type='search']:focus {
  border-color: #1d5dfb;
  box-shadow: 0 0 0 3px rgba(29, 93, 251, 0.14);
}

.compact-field {
  gap: 6px;
}

.compact-field input[type='search'] {
  height: 38px;
}

.field input[type='color'] {
  width: 100%;
  height: 42px;
  padding: 3px;
  background: #f8fafc;
  border: 1px solid #dbe1ea;
  border-radius: 8px;
  cursor: pointer;
}

.status-line {
  display: flex;
  justify-content: space-between;
  min-height: 18px;
  color: #7b8492;
  font-size: 12px;
  font-weight: 700;
}

.browser-heading {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 28px;
  color: #111827;
  font-size: 13px;
  font-weight: 800;
}

.back-button {
  height: 28px;
  padding: 0 10px;
  border: 1px solid #dbe1ea;
  color: #4b5563;
  background: #ffffff;
  border-radius: 7px;
  cursor: pointer;
  font-size: 12px;
  font-weight: 800;
}

.icon-set-list {
  display: grid;
  gap: 8px;
  max-height: 302px;
  overflow: auto;
  padding-right: 4px;
}

.icon-set-choice {
  display: grid;
  grid-template-columns: 44px minmax(0, 1fr);
  align-items: center;
  gap: 10px;
  min-height: 54px;
  padding: 8px;
  border: 1px solid #e1e6ef;
  color: #111827;
  text-align: left;
  background: #ffffff;
  border-radius: 8px;
  cursor: pointer;
}

.icon-set-choice:hover {
  border-color: #1d5dfb;
  box-shadow: 0 0 0 3px rgba(29, 93, 251, 0.1);
}

.set-prefix {
  display: grid;
  width: 40px;
  height: 36px;
  place-items: center;
  color: #ffffff;
  background: #111827;
  border-radius: 7px;
  font-size: 12px;
  font-weight: 900;
  overflow: hidden;
  text-transform: uppercase;
}

.set-detail {
  display: grid;
  min-width: 0;
  gap: 2px;
}

.set-detail strong,
.set-detail small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.set-detail small {
  color: #7b8492;
  font-size: 12px;
}

.icon-grid {
  display: grid;
  grid-template-columns: repeat(5, 42px);
  justify-content: space-between;
  gap: 8px;
  max-height: 302px;
  overflow: auto;
  padding-right: 4px;
}

.icon-spacer {
  grid-column: 1 / -1;
  pointer-events: none;
}

.icon-spacer.top {
  height: var(--icon-top-spacer);
}

.icon-spacer.bottom {
  height: var(--icon-bottom-spacer);
}

.icon-choice {
  display: grid;
  width: 42px;
  height: 42px;
  place-items: center;
  border: 1px solid #e1e6ef;
  background: #ffffff;
  border-radius: 8px;
  cursor: pointer;
}

.icon-choice.active {
  border-color: #1d5dfb;
  box-shadow: 0 0 0 3px rgba(29, 93, 251, 0.12);
}

.icon-choice img {
  width: 24px;
  height: 24px;
}

.empty-icons {
  grid-column: 1 / -1;
  display: grid;
  min-height: 82px;
  place-items: center;
  color: #8a93a1;
  font-size: 13px;
}

.swatches {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 7px;
}

.swatches button {
  aspect-ratio: 1;
  border: 1px solid rgba(15, 23, 42, 0.14);
  border-radius: 7px;
  cursor: pointer;
}

.range-field {
  display: grid;
  grid-template-columns: 1fr auto;
  align-items: center;
}

.range-field > input[type='range'] {
  grid-column: 1 / -1;
  width: 100%;
  accent-color: #1d5dfb;
}

.range-field strong {
  color: #111827;
  font-size: 13px;
}

.number-control {
  display: flex;
  align-items: center;
  gap: 6px;
}

.number-control input {
  width: 72px;
  height: 34px;
  padding: 0 8px;
  color: #111827;
  text-align: right;
  background: #f8fafc;
  border: 1px solid #dbe1ea;
  border-radius: 7px;
  outline: 0;
}

.number-control input:focus {
  border-color: #1d5dfb;
  box-shadow: 0 0 0 3px rgba(29, 93, 251, 0.12);
}

.shadow-list {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 6px;
}

.shadow-list button {
  height: 34px;
  border: 1px solid #d9dfe8;
  color: #687080;
  background: #ffffff;
  border-radius: 7px;
  cursor: pointer;
  font-size: 12px;
  font-weight: 800;
}

.shadow-list button.active {
  color: #ffffff;
  background: #111827;
  border-color: #111827;
}

.workbench {
  position: relative;
  display: grid;
  grid-template-rows: 72px 1fr;
  min-height: 100vh;
}

.topbar {
  z-index: 2;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 22px;
  height: 72px;
  background: rgba(255, 255, 255, 0.9);
  border-bottom: 1px solid #e7eaf0;
  backdrop-filter: blur(10px);
}

.icon-button {
  display: grid;
  width: 42px;
  height: 42px;
  place-items: center;
  color: #252932;
  background: #ffffff;
  border: 1px solid #dce2ec;
  border-radius: 8px;
  cursor: pointer;
  font-size: 25px;
}

.preset-strip {
  display: flex;
  align-items: center;
  gap: 10px;
  color: #8a93a1;
  font-size: 12px;
  font-weight: 800;
  text-transform: uppercase;
}

.preset {
  display: grid;
  width: 48px;
  height: 48px;
  place-items: center;
  border: 0;
  border-radius: 8px;
  cursor: pointer;
  box-shadow: inset 0 0 0 1px rgba(15, 23, 42, 0.12);
}

.preset-glyph {
  font-size: 24px;
  font-weight: 900;
}

.canvas-wrap {
  position: relative;
  display: grid;
  min-height: 0;
  place-items: center;
  overflow: auto;
  padding: 64px;
}

.grid-floor {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(#eef1f5 1px, transparent 1px),
    linear-gradient(90deg, #eef1f5 1px, transparent 1px);
  background-size: 18px 18px;
}

.logo-frame {
  position: relative;
  display: grid;
  max-width: min(62vh, 70vw);
  max-height: min(62vh, 70vw);
  place-items: center;
  overflow: hidden;
  outline: 1px dashed rgba(15, 23, 42, 0.08);
}

.logo-icon {
  display: grid;
  place-items: center;
}

.logo-icon :deep(svg) {
  display: block;
  width: 100%;
  height: 100%;
  color: inherit;
}

.export-panel h1 {
  margin: 5px 0 0;
  color: #15171c;
  font-size: 30px;
  line-height: 1.05;
}

.eyebrow {
  margin: 0;
  color: #8a93a1;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0;
  text-transform: uppercase;
}

.icon-name {
  margin: 8px 0 0;
  color: #687080;
  font-size: 14px;
  overflow-wrap: anywhere;
}

.preview-card {
  display: grid;
  place-items: center;
  padding: 26px;
  background:
    linear-gradient(45deg, #eef1f5 25%, transparent 25%),
    linear-gradient(-45deg, #eef1f5 25%, transparent 25%),
    linear-gradient(45deg, transparent 75%, #eef1f5 75%),
    linear-gradient(-45deg, transparent 75%, #eef1f5 75%);
  background-color: #ffffff;
  background-position:
    0 0,
    0 10px,
    10px -10px,
    -10px 0;
  background-size: 20px 20px;
  border: 1px solid #e0e6ef;
  border-radius: 8px;
}

.mini-logo {
  display: grid;
  width: 140px !important;
  height: 140px !important;
  max-width: 140px;
  max-height: 140px;
  place-items: center;
}

.download-actions {
  display: grid;
  gap: 10px;
}

.export-size-presets {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 6px;
}

.export-size-presets button {
  height: 32px;
  border: 1px solid #d9dfe8;
  color: #4b5563;
  background: #ffffff;
  border-radius: 7px;
  cursor: pointer;
  font-size: 12px;
  font-weight: 800;
}

.export-size-presets button:hover {
  border-color: #1d5dfb;
  color: #1d5dfb;
}

.download-actions button {
  height: 46px;
  border: 1px solid #1d5dfb;
  color: #ffffff;
  background: #1d5dfb;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 800;
}

.download-actions button + button {
  color: #1d5dfb;
  background: #ffffff;
}

.download-actions button:disabled {
  cursor: not-allowed;
  opacity: 0.55;
}

.meta-list {
  display: grid;
  gap: 12px;
  padding-top: 12px;
  border-top: 1px solid #e7eaf0;
}

.meta-list div {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  color: #7b8492;
  font-size: 13px;
}

.meta-list strong {
  color: #111827;
}

@media (max-width: 1120px) {
  .app-shell {
    grid-template-columns: 280px minmax(360px, 1fr);
  }

  .export-panel {
    display: none;
  }
}

@media (max-width: 760px) {
  .app-shell {
    display: flex;
    min-height: 100vh;
    flex-direction: column;
    overflow: visible;
  }

  .tool-panel,
  .export-panel {
    min-height: auto;
    border: 0;
  }

  .tool-panel {
    order: 2;
  }

  .workbench {
    order: 1;
    min-height: 72vh;
    grid-template-rows: auto 1fr;
  }

  .topbar {
    height: auto;
    flex-wrap: wrap;
    padding: 12px;
  }

  .canvas-wrap {
    padding: 30px;
  }

  .logo-frame {
    max-width: min(78vw, 420px);
    max-height: min(78vw, 420px);
  }
}
</style>
