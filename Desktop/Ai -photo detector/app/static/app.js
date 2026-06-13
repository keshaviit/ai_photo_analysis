document.addEventListener('DOMContentLoaded', () => {
    // Current application state
    const state = {
        activeTab: 'search',
        categories: [],
        duplicates: [],
        currentCategory: null
    };

    // DOM Elements
    const navItems = document.querySelectorAll('.nav-item');
    const tabContents = document.querySelectorAll('.tab-content');
    const searchInput = document.getElementById('search-input');
    const searchBtn = document.getElementById('search-btn');
    const photosGrid = document.getElementById('photos-grid');
    const resultsHeader = document.querySelector('.results-header');
    const resultsCount = document.getElementById('results-count');
    
    // Upload & Scan elements
    const dropzone = document.getElementById('upload-dropzone');
    const fileInput = document.getElementById('file-input');
    const uploadProgressContainer = document.getElementById('upload-progress-container');
    const uploadProgressFill = document.getElementById('upload-progress-fill');
    const uploadProgressStatus = document.getElementById('upload-progress-status');
    const startScanBtn = document.getElementById('start-scan-btn');
    const directoryPathInput = document.getElementById('directory-path-input');
    const scanStatusCard = document.getElementById('scan-status-card');
    const scanStatusTitle = document.getElementById('scan-status-title');
    const scanStatusDesc = document.getElementById('scan-status-desc');
    
    // Categories elements
    const foldersGrid = document.getElementById('folders-grid');
    const categoryViewer = document.getElementById('category-viewer');
    const currentCategoryTitle = document.getElementById('current-category-title');
    const categoryPhotosGrid = document.getElementById('category-photos-grid');
    const backToFoldersBtn = document.getElementById('back-to-folders-btn');
    
    // Duplicates elements
    const duplicateThreshold = document.getElementById('duplicate-threshold');
    const thresholdVal = document.getElementById('threshold-val');
    const refreshDuplicatesBtn = document.getElementById('refresh-duplicates-btn');
    const duplicatesContainer = document.getElementById('duplicates-container');
    
    // Modal Lightbox elements
    const photoModal = document.getElementById('photo-modal');
    const modalImg = document.getElementById('modal-img');
    const modalFilename = document.getElementById('modal-filename');
    const modalDate = document.getElementById('modal-date');
    const modalCategory = document.getElementById('modal-category');
    const modalDimensions = document.getElementById('modal-dimensions');
    const modalFilesize = document.getElementById('modal-filesize');
    const modalPhash = document.getElementById('modal-phash');
    const modalOcrText = document.getElementById('modal-ocr-text');
    const modalOcrSection = document.getElementById('modal-ocr-section');
    const modalDownloadLink = document.getElementById('modal-download-link');
    const closeModalBtn = document.querySelector('.close-modal-btn');

    /* ==========================================================================
       Tab Navigation
       ========================================================================== */
    navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const tabName = item.getAttribute('data-tab');
            switchTab(tabName);
        });
    });

    function switchTab(tabName) {
        state.activeTab = tabName;
        
        // Update active class in menu
        navItems.forEach(item => {
            if (item.getAttribute('data-tab') === tabName) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });

        // Toggle tab visibility
        tabContents.forEach(content => {
            if (content.id === `${tabName}-tab`) {
                content.classList.add('active');
            } else {
                content.classList.remove('active');
            }
        });

        // Trigger loading actions based on active tab
        if (tabName === 'categories') {
            loadCategories();
        } else if (tabName === 'duplicates') {
            loadDuplicates();
        } else if (tabName === 'search') {
            // Load all photos on default search page
            loadDefaultPhotos();
        }
    }

    /* ==========================================================================
       Search Features
       ========================================================================== */
    searchBtn.addEventListener('click', performSearch);
    searchInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') performSearch();
    });

    async function performSearch() {
        const query = searchInput.value.trim();
        if (!query) {
            loadDefaultPhotos();
            return;
        }

        const searchType = document.querySelector('input[name="search-type"]:checked').value;
        photosGrid.innerHTML = '<div class="empty-state"><div class="empty-icon">⏳</div><h3>Searching...</h3><p>Consulting our AI vector index...</p></div>';
        resultsHeader.style.display = 'none';

        try {
            const response = await fetch(`/api/search?q=${encodeURIComponent(query)}&type=${searchType}&limit=30`);
            if (!response.ok) throw new Error('Search failed');
            
            const results = await response.json();
            renderSearchResults(results);
        } catch (error) {
            console.error('Search error:', error);
            showConnectionError(photosGrid, 'Search Query Failed', performSearch);
        }
    }

    // Displays all photos on default explore view using categories endpoint (SQL-only, no CLIP)
    async function loadDefaultPhotos() {
        photosGrid.innerHTML = '';
        resultsHeader.style.display = 'none';
        try {
            const response = await fetch('/api/categories');
            if (!response.ok) throw new Error('Load failed');
            const categories = await response.json();
            
            // Flatten all photos across all categories
            const allPhotos = [];
            categories.forEach(cat => {
                cat.photos.forEach(photo => allPhotos.push(photo));
            });
            
            if (allPhotos.length === 0) {
                renderEmptyLibraryState();
            } else {
                resultsHeader.style.display = 'flex';
                resultsCount.textContent = `${allPhotos.length} photo${allPhotos.length > 1 ? 's' : ''} in library`;
                allPhotos.forEach(photo => {
                    const card = createPhotoCard(photo);
                    photosGrid.appendChild(card);
                });
            }
        } catch (error) {
            console.error('Explore load failed:', error);
            showConnectionError(photosGrid, 'Connection Failed', loadDefaultPhotos);
        }
    }

    function renderEmptyLibraryState() {
        photosGrid.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">🖼️</div>
                <h3>Your library is empty</h3>
                <p>Upload files or run a directory scan under the "Add Photos" tab to get started.</p>
            </div>`;
        resultsHeader.style.display = 'none';
    }

    function renderSearchResults(results, showScores = true) {
        photosGrid.innerHTML = '';
        
        if (results.length === 0) {
            photosGrid.innerHTML = `
                <div class="empty-state">
                    <div class="empty-icon">🔍</div>
                    <h3>No matches found</h3>
                    <p>Try using different keywords or describe your photo differently.</p>
                </div>`;
            resultsHeader.style.display = 'none';
            return;
        }

        resultsHeader.style.display = 'flex';
        resultsCount.textContent = `${results.length} item${results.length > 1 ? 's' : ''} found`;

        results.forEach(item => {
            const photo = item.photo;
            const score = item.similarity;
            
            const card = createPhotoCard(photo, showScores ? score : null);
            photosGrid.appendChild(card);
        });
    }

    function createPhotoCard(photo, score = null) {
        const card = document.createElement('div');
        card.className = 'photo-card';
        
        // Setup image URL serving from the static uploads folder
        const imgUrl = `/${photo.filepath}`;
        
        let similarityBadge = '';
        if (score !== null && score < 1.0) {
            const matchPercentage = Math.round(score * 100);
            similarityBadge = `<div class="similarity-badge">${matchPercentage}% Match</div>`;
        } else if (score === 1.0) {
            similarityBadge = `<div class="similarity-badge" style="background-color: var(--success-light); color: var(--success-color);">Text Match</div>`;
        }

        card.innerHTML = `
            ${similarityBadge}
            <div class="photo-img-wrapper">
                <img src="${imgUrl}" alt="${photo.filename}" loading="lazy">
            </div>
            <div class="photo-info">
                <h4 class="photo-title" title="${photo.filename}">${photo.filename}</h4>
                <div class="photo-meta">
                    <span>${photo.category || 'Other'}</span>
                    <span>${formatBytes(photo.file_size)}</span>
                </div>
            </div>
        `;

        card.addEventListener('click', () => openLightbox(photo));
        return card;
    }

    /* ==========================================================================
       Upload & Scan Operations
       ========================================================================== */
    
    // Drag and drop events
    dropzone.addEventListener('click', () => fileInput.click());
    
    ['dragenter', 'dragover'].forEach(eventName => {
        dropzone.addEventListener(eventName, (e) => {
            e.preventDefault();
            dropzone.classList.add('dragover');
        }, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
        dropzone.addEventListener(eventName, (e) => {
            e.preventDefault();
            dropzone.classList.remove('dragover');
        }, false);
    });

    dropzone.addEventListener('drop', (e) => {
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            handleFileUpload(files[0]);
        }
    });

    fileInput.addEventListener('change', (e) => {
        if (fileInput.files.length > 0) {
            handleFileUpload(fileInput.files[0]);
        }
    });

    function handleFileUpload(file) {
        const formData = new FormData();
        formData.append('file', file);

        uploadProgressContainer.style.display = 'block';
        uploadProgressFill.style.width = '0%';
        uploadProgressStatus.textContent = 'Preparing upload...';

        const xhr = new XMLHttpRequest();
        
        // Native upload progress tracking
        xhr.upload.addEventListener('progress', (e) => {
            if (e.lengthComputable) {
                const percentComplete = Math.round((e.loaded / e.total) * 100);
                uploadProgressFill.style.width = `${percentComplete}%`;
                uploadProgressStatus.textContent = `Uploading file... ${percentComplete}%`;
            }
        });

        xhr.addEventListener('load', () => {
            if (xhr.status === 201) {
                uploadProgressFill.style.width = '100%';
                uploadProgressStatus.textContent = 'Upload complete! Image processed successfully.';
                uploadProgressStatus.style.color = 'var(--success-color)';
                
                // Clear state helper
                setTimeout(() => {
                    uploadProgressContainer.style.display = 'none';
                    uploadProgressStatus.style.color = '';
                    // Redirect to Explore tab to view the file
                    switchTab('search');
                }, 1500);
            } else {
                handleUploadError(xhr.responseText);
            }
        });

        xhr.addEventListener('error', () => handleUploadError('Network connection lost'));
        
        xhr.open('POST', '/api/photos/upload');
        xhr.send(formData);
    }

    function handleUploadError(errorText) {
        uploadProgressFill.style.backgroundColor = '#ef4444';
        uploadProgressStatus.style.color = '#ef4444';
        try {
            const err = JSON.parse(errorText);
            uploadProgressStatus.textContent = `Error: ${err.detail || 'Upload failed'}`;
        } catch {
            uploadProgressStatus.textContent = 'Error: Processing failed.';
        }
    }

    // Directory Scan trigger
    startScanBtn.addEventListener('click', async () => {
        const directoryPath = directoryPathInput.value.trim();
        if (!directoryPath) {
            alert('Please input a valid local folder path.');
            return;
        }

        startScanBtn.disabled = true;
        startScanBtn.textContent = 'Initializing...';
        
        try {
            const response = await fetch('/api/photos/scan-folder', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ directory_path: directoryPath })
            });

            const data = await response.json();
            
            if (response.ok) {
                scanStatusCard.style.display = 'flex';
                scanStatusTitle.textContent = data.status === 'processing' ? 'Scan Initialized' : 'Scan Complete';
                scanStatusDesc.textContent = data.message;
                
                // Reset inputs
                directoryPathInput.value = '';
            } else {
                alert(`Error: ${data.detail || 'Directory scan initialization failed'}`);
            }
        } catch (error) {
            console.error('Scan folder error:', error);
            alert('Failed to connect to scanner service.');
        } finally {
            startScanBtn.disabled = false;
            startScanBtn.querySelector('span').textContent = 'Start Scanning Folder';
        }
    });

    /* ==========================================================================
       Categories View
       ========================================================================== */
    backToFoldersBtn.addEventListener('click', () => {
        categoryViewer.style.display = 'none';
        foldersGrid.style.display = 'grid';
    });

    async function loadCategories() {
        foldersGrid.style.display = 'grid';
        categoryViewer.style.display = 'none';
        foldersGrid.innerHTML = '<div style="grid-column: 1/-1; text-align: center; padding: 48px;">Loading category groups...</div>';

        try {
            const response = await fetch('/api/categories');
            if (!response.ok) throw new Error('Failed to fetch categories');
            
            state.categories = await response.json();
            renderCategoryFolders(state.categories);
        } catch (error) {
            console.error('Categories error:', error);
            showConnectionError(foldersGrid, 'Failed to Load Categories', loadCategories);
        }
    }

    function renderCategoryFolders(categories) {
        foldersGrid.innerHTML = '';
        
        // Defined categories
        const predefined = [
            { id: 'Animal/Pet', label: 'Animals & Pets', colorClass: 'folder-teal' },
            { id: 'Landscape/Nature', label: 'Landscapes & Nature', colorClass: 'folder-blue' },
            { id: 'Portrait/People', label: 'Portraits & People', colorClass: 'folder-indigo' },
            { id: 'Document/Receipt', label: 'Documents & Receipts', colorClass: 'folder-amber' },
            { id: 'Other', label: 'Unclassified / Other', colorClass: 'folder-slate' }
        ];

        // Map categories list to easily lookup photos
        const photoMap = {};
        categories.forEach(item => {
            photoMap[item.category] = item.photos;
        });

        const folderSvg = `
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z"></path>
            </svg>
        `;

        predefined.forEach(group => {
            const photos = photoMap[group.id] || [];
            const count = photos.length;
            
            const card = document.createElement('div');
            card.className = 'folder-card';
            card.innerHTML = `
                <div class="folder-icon ${group.colorClass}">${folderSvg}</div>
                <div class="folder-name">${group.label}</div>
                <div class="folder-count">${count} photo${count !== 1 ? 's' : ''}</div>
            `;
            
            card.addEventListener('click', () => openCategoryView(group.label, photos));
            foldersGrid.appendChild(card);
        });
    }

    function openCategoryView(label, photos) {
        state.currentCategory = { label, photos };
        
        foldersGrid.style.display = 'none';
        categoryViewer.style.display = 'block';
        currentCategoryTitle.textContent = label;
        
        categoryPhotosGrid.innerHTML = '';
        
        if (photos.length === 0) {
            categoryPhotosGrid.innerHTML = `
                <div class="empty-state">
                    <div class="empty-icon">📁</div>
                    <h3>Folder is empty</h3>
                    <p>No photos have been grouped under this category yet.</p>
                </div>`;
            return;
        }

        photos.forEach(photo => {
            const card = createPhotoCard(photo);
            categoryPhotosGrid.appendChild(card);
        });
    }

    /* ==========================================================================
       Duplicates Check
       ========================================================================== */
    duplicateThreshold.addEventListener('input', () => {
        thresholdVal.textContent = duplicateThreshold.value;
    });

    refreshDuplicatesBtn.addEventListener('click', loadDuplicates);

    async function loadDuplicates() {
        duplicatesContainer.innerHTML = '<div style="text-align: center; padding: 48px;">Analyzing visual database hashes...</div>';
        const val = duplicateThreshold.value;

        try {
            const response = await fetch(`/api/duplicates?threshold=${val}`);
            if (!response.ok) throw new Error('Failed to retrieve duplicates');
            
            state.duplicates = await response.json();
            renderDuplicates(state.duplicates);
        } catch (error) {
            console.error('Duplicates fetch error:', error);
            showConnectionError(duplicatesContainer, 'Failed to Analyze Duplicates', loadDuplicates);
        }
    }

    function renderDuplicates(groups) {
        duplicatesContainer.innerHTML = '';
        
        if (groups.length === 0) {
            duplicatesContainer.innerHTML = `
                <div class="empty-state">
                    <div class="empty-icon">✨</div>
                    <h3>No duplicates found</h3>
                    <p>Excellent! Your photo collection contains only unique images at the current sensitivity.</p>
                </div>`;
            return;
        }

        groups.forEach((group, index) => {
            const card = document.createElement('div');
            card.className = 'duplicate-group-card';
            
            card.innerHTML = `
                <div class="duplicate-group-title">Duplicate Set #${index + 1} (pHash: ${group.phash})</div>
                <div class="duplicate-group-grid"></div>
            `;
            
            const grid = card.querySelector('.duplicate-group-grid');
            group.photos.forEach(photo => {
                const photoCard = createPhotoCard(photo);
                grid.appendChild(photoCard);
            });
            
            duplicatesContainer.appendChild(card);
        });
    }

    /* ==========================================================================
       Lightbox Modal Viewer
       ========================================================================== */
    function openLightbox(photo) {
        modalImg.src = `/${photo.filepath}`;
        modalFilename.textContent = photo.filename;
        
        // Parse date
        const dateObj = new Date(photo.created_at);
        modalDate.textContent = `Imported on: ${dateObj.toLocaleDateString()} at ${dateObj.toLocaleTimeString()}`;
        
        modalCategory.textContent = photo.category || 'Other';
        modalDimensions.textContent = `Resolution: ${photo.width || '--'} x ${photo.height || '--'} px`;
        modalFilesize.textContent = `File Size: ${formatBytes(photo.file_size)}`;
        modalPhash.textContent = `pHash Signature: ${photo.phash || '--'}`;
        
        // Handle OCR Text box visibility
        if (photo.ocr_text) {
            modalOcrSection.style.display = 'block';
            modalOcrText.textContent = photo.ocr_text;
        } else {
            modalOcrSection.style.display = 'none';
        }

        modalDownloadLink.href = `/${photo.filepath}`;
        
        // Open the modal
        photoModal.style.display = 'block';
        document.body.style.overflow = 'hidden'; // prevent scrolling behind modal
    }

    function closeModal() {
        photoModal.style.display = 'none';
        document.body.style.overflow = ''; // restore scrolling
    }

    closeModalBtn.addEventListener('click', closeModal);
    window.addEventListener('click', (e) => {
        if (e.target === photoModal) closeModal();
    });

    /* ==========================================================================
       Helpers & Initialization
       ========================================================================== */
    function showConnectionError(container, message, retryCallback) {
        container.innerHTML = `
            <div class="empty-state error-state" style="grid-column: 1 / -1; padding: 48px 24px; text-align: center; display: flex; flex-direction: column; align-items: center; justify-content: center;">
                <div class="empty-icon" style="color: #ef4444; width: 64px; height: 64px; margin-bottom: 16px; opacity: 0.8;">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
                    </svg>
                </div>
                <h3 style="font-size: 18px; font-weight: 600; margin-bottom: 8px; color: var(--text-primary);">${message}</h3>
                <p style="font-size: 14px; color: var(--text-secondary); max-width: 380px; margin: 0 auto 16px; line-height: 1.5;">
                    Could not connect to the backend server. The engine might be loading models or offline.
                </p>
                <button class="btn-secondary retry-btn" style="display: inline-block; width: auto; padding: 10px 24px; font-size: 14px; font-weight: 600;">
                    Retry Connection
                </button>
            </div>
        `;
        const retryBtn = container.querySelector('.retry-btn');
        if (retryBtn && retryCallback) {
            retryBtn.addEventListener('click', (e) => {
                e.preventDefault();
                retryBtn.textContent = 'Retrying...';
                retryBtn.disabled = true;
                setTimeout(retryCallback, 300); // slight delay for visual transition
            });
        }
    }

    function formatBytes(bytes, decimals = 2) {
        if (!bytes) return '0 Bytes';
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
    }

    // Default Load on initialization
    loadDefaultPhotos();
});
