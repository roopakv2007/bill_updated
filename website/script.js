// Language state
let currentLang = 'en'; // 'en' or 'ta'

// Language translations for dynamic content
const translations = {
    en: {
        description: 'Description',
        qty: 'Qty',
        rate: 'Rate',
        amount: 'Amount',
        langButton: 'தமிழ்'
    },
    ta: {
        description: 'விளக்கம்',
        qty: 'அளவு',
        rate: 'விலை',
        amount: 'தொகை',
        langButton: 'English'
    }
};

// Toggle language
function toggleLanguage() {
    currentLang = currentLang === 'en' ? 'ta' : 'en';

    // Update all elements with data-lang attributes
    const elements = document.querySelectorAll('[data-lang-en]');
    elements.forEach(el => {
        const text = currentLang === 'en' ? el.getAttribute('data-lang-en') : el.getAttribute('data-lang-ta');
        el.textContent = text;
    });

    // Update language button text
    document.getElementById('langText').textContent = translations[currentLang].langButton;

    // Regenerate item rows with new language
    const numItems = parseInt(document.getElementById('numItems').value) || 0;
    if (numItems > 0) {
        generateItemRows();
    }
}

// Number to Words Conversion
function numberToWords(num) {
    if (num === 0) return 'Zero Rupees Only';

    const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    const teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];

    function convertLessThanThousand(n) {
        if (n === 0) return '';

        let result = '';

        if (n >= 100) {
            result += ones[Math.floor(n / 100)] + ' Hundred ';
            n %= 100;
        }

        if (n >= 20) {
            result += tens[Math.floor(n / 10)] + ' ';
            n %= 10;
        } else if (n >= 10) {
            result += teens[n - 10] + ' ';
            return result;
        }

        if (n > 0) {
            result += ones[n] + ' ';
        }

        return result;
    }

    let result = '';

    if (num >= 10000000) { // Crores
        result += convertLessThanThousand(Math.floor(num / 10000000)) + 'Crore ';
        num %= 10000000;
    }

    if (num >= 100000) { // Lakhs
        result += convertLessThanThousand(Math.floor(num / 100000)) + 'Lakh ';
        num %= 100000;
    }

    if (num >= 1000) { // Thousands
        result += convertLessThanThousand(Math.floor(num / 1000)) + 'Thousand ';
        num %= 1000;
    }

    if (num > 0) {
        result += convertLessThanThousand(num);
    }

    return result.trim() + ' Rupees Only';
}

// Format currency
function formatCurrency(amount) {
    return '₹' + parseFloat(amount).toFixed(2);
}

// Generate dynamic item rows in the form
function generateItemRows() {
    const numItems = parseInt(document.getElementById('numItems').value) || 0;
    const container = document.getElementById('itemsContainer');

    container.innerHTML = '';

    const lang = translations[currentLang];

    for (let i = 1; i <= numItems; i++) {
        const itemRow = document.createElement('div');
        itemRow.className = 'item-row';
        itemRow.innerHTML = `
            <div class="item-input-group">
                <label>${lang.description}</label>
                <input type="text" class="item-desc" data-index="${i}" required>
            </div>
            <div class="item-input-group">
                <label>${lang.qty}</label>
                <input type="number" class="item-qty" data-index="${i}" min="1" value="1" required>
            </div>
            <div class="item-input-group">
                <label>${lang.rate}</label>
                <input type="number" class="item-rate" data-index="${i}" min="0" step="0.01" value="0" required>
            </div>
            <div class="item-input-group">
                <label>${lang.amount}</label>
                <input type="text" class="item-amount" data-index="${i}" value="₹0.00" readonly>
            </div>
        `;
        container.appendChild(itemRow);
    }

    // Add event listeners for auto-calculation
    attachCalculationListeners();
}

// Attach event listeners for real-time calculation
function attachCalculationListeners() {
    const qtyInputs = document.querySelectorAll('.item-qty');
    const rateInputs = document.querySelectorAll('.item-rate');

    qtyInputs.forEach(input => {
        input.addEventListener('input', calculateItemAmount);
    });

    rateInputs.forEach(input => {
        input.addEventListener('input', calculateItemAmount);
    });
}

// Calculate individual item amount
function calculateItemAmount(event) {
    const index = event.target.dataset.index;
    const qty = parseFloat(document.querySelector(`.item-qty[data-index="${index}"]`).value) || 0;
    const rate = parseFloat(document.querySelector(`.item-rate[data-index="${index}"]`).value) || 0;
    const amount = qty * rate;

    document.querySelector(`.item-amount[data-index="${index}"]`).value = formatCurrency(amount);

    // Update total
    calculateTotal();
}

// Calculate total amount
function calculateTotal() {
    const amountInputs = document.querySelectorAll('.item-amount');
    let total = 0;

    amountInputs.forEach(input => {
        const value = input.value.replace('₹', '').replace(',', '');
        total += parseFloat(value) || 0;
    });

    document.getElementById('formTotal').textContent = formatCurrency(total);
    document.getElementById('formTotalWords').textContent = numberToWords(Math.floor(total));
}

// Handle form submission
function handleFormSubmit(event) {
    event.preventDefault();

    // Get customer details
    const customerName = document.getElementById('customerName').value;
    const phoneNumber = document.getElementById('phoneNumber').value;

    // Fill customer details in invoice
    document.getElementById('displayCustomerName').textContent = customerName;
    document.getElementById('displayPhoneNumber').textContent = phoneNumber;

    // Get all items
    const numItems = parseInt(document.getElementById('numItems').value);
    const items = [];

    for (let i = 1; i <= numItems; i++) {
        const desc = document.querySelector(`.item-desc[data-index="${i}"]`).value;
        const qty = document.querySelector(`.item-qty[data-index="${i}"]`).value;
        const rate = parseFloat(document.querySelector(`.item-rate[data-index="${i}"]`).value);
        const amount = parseFloat(document.querySelector(`.item-amount[data-index="${i}"]`).value.replace('₹', ''));

        items.push({ desc, qty, rate, amount });
    }

    // Fill invoice table
    fillInvoiceTable(items);

    // Calculate and display total
    const total = items.reduce((sum, item) => sum + item.amount, 0);
    document.getElementById('displayTotal').textContent = formatCurrency(total);
    document.getElementById('displayTotalWords').textContent = numberToWords(Math.floor(total));

    // Hide form, show invoice and download button
    document.getElementById('formContainer').style.display = 'none';
    document.getElementById('invoiceTemplate').style.display = 'flex';
    document.getElementById('downloadContainer').style.display = 'flex';

    // Scroll to invoice
    document.getElementById('invoiceTemplate').scrollIntoView({ behavior: 'smooth' });
}

// Fill invoice table with items
function fillInvoiceTable(items) {
    const tbody = document.getElementById('invoiceTableBody');
    tbody.innerHTML = '';

    // Add filled rows
    items.forEach((item, index) => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td class="col-sl">${index + 1}</td>
            <td class="col-desc">${item.desc}</td>
            <td class="col-qty">${item.qty}</td>
            <td class="col-rate">${formatCurrency(item.rate)}</td>
            <td class="col-amount">${formatCurrency(item.amount)}</td>
        `;
        tbody.appendChild(row);
    });

    // Add empty rows to fill up to 15 total rows
    const emptyRowsNeeded = 15 - items.length;
    for (let i = 0; i < emptyRowsNeeded; i++) {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
        `;
        tbody.appendChild(row);
    }
}

// Download invoice as image
function downloadInvoice() {
    const invoice = document.getElementById('invoiceTemplate');
    const downloadBtn = document.getElementById('downloadBtn');

    // Check if html2canvas is loaded
    if (typeof html2canvas === 'undefined') {
        alert('Error: Image library not loaded. Please refresh the page and try again.');
        return;
    }

    // Show loading state
    const originalText = downloadBtn.textContent;
    downloadBtn.textContent = currentLang === 'en' ? '⏳ Generating...' : '⏳ உருவாக்குகிறது...';
    downloadBtn.disabled = true;

    // Use html2canvas to capture the invoice
    html2canvas(invoice, {
        scale: 2,
        useCORS: true,
        allowTaint: true,
        logging: false,
        backgroundColor: '#ffffff',
        windowWidth: invoice.scrollWidth,
        windowHeight: invoice.scrollHeight,
        onclone: function (clonedDoc) {
            // Ensure all styles are applied to cloned document
            const clonedInvoice = clonedDoc.getElementById('invoiceTemplate');
            if (clonedInvoice) {
                clonedInvoice.style.display = 'flex';
            }
        }
    }).then(canvas => {
        try {
            // Create download link
            const link = document.createElement('a');
            const customerName = document.getElementById('displayCustomerName').textContent || 'Customer';
            const date = new Date().toISOString().split('T')[0];
            const fileName = `Invoice_${customerName.replace(/\s+/g, '_')}_${date}.png`;

            link.download = fileName;
            link.href = canvas.toDataURL('image/png');

            // Trigger download
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            // Reset button
            downloadBtn.textContent = originalText;
            downloadBtn.disabled = false;

            // Show success message
            alert(currentLang === 'en' ?
                '✅ Invoice downloaded successfully!' :
                '✅ பில் வெற்றிகரமாக பதிவிறக்கப்பட்டது!');
        } catch (error) {
            console.error('Download error:', error);
            alert('Error downloading invoice. Please try again.');
            downloadBtn.textContent = originalText;
            downloadBtn.disabled = false;
        }
    }).catch(error => {
        console.error('html2canvas error:', error);
        alert('Error generating image. Please try again.');
        downloadBtn.textContent = originalText;
        downloadBtn.disabled = false;
    });
}

// Create new invoice (reset form)
function createNewInvoice() {
    // Reset form
    document.getElementById('invoiceForm').reset();
    document.getElementById('numItems').value = 1;
    generateItemRows();

    // Show form, hide invoice and download button
    document.getElementById('formContainer').style.display = 'block';
    document.getElementById('invoiceTemplate').style.display = 'none';
    document.getElementById('downloadContainer').style.display = 'none';

    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

// Edit invoice (go back to form)
function editInvoice() {
    // Show form, hide invoice and download button
    document.getElementById('formContainer').style.display = 'block';
    document.getElementById('invoiceTemplate').style.display = 'none';
    document.getElementById('downloadContainer').style.display = 'none';

    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function () {
    // Generate initial item row
    generateItemRows();

    // Event listener for language toggle
    document.getElementById('languageToggle').addEventListener('click', toggleLanguage);

    // Event listener for number of items change
    document.getElementById('numItems').addEventListener('change', generateItemRows);

    // Event listener for form submission
    document.getElementById('invoiceForm').addEventListener('submit', handleFormSubmit);

    // Event listener for download button
    document.getElementById('downloadBtn').addEventListener('click', downloadInvoice);

    // Event listener for edit invoice button
    document.getElementById('editInvoiceBtn').addEventListener('click', editInvoice);

    // Event listener for new invoice button
    document.getElementById('newInvoiceBtn').addEventListener('click', createNewInvoice);
});
