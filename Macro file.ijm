// ===== Peripheral vs Inner MGV macro =====
// Assumes 3 open windows named exactly: "HMGB1", "Mito", "DAPI"
// "DAPI" = binary mask of whole image (nuclei = foreground)
// Whole-cell ROI = ACTIVE SELECTION on any window before running
// ==========================================

erosionPixels = 10;   // change here if needed

// --- ask for a cell label so output rows are identifiable ---
cellName = getString("Cell / image label:", "cell1");

// --- confirm there is an active selection ---
if (selectionType() == -1) exit("Draw the whole-cell ROI first (active selection).");

roiManager("reset");
roiManager("Add");              // index 0 = whole-cell ROI

// --- build INNER ROI by eroding the whole-cell ROI ---
roiManager("Select", 0);
run("Enlarge...", "enlarge=-" + erosionPixels + " pixel");
roiManager("Add");              // index 1 = inner ROI

// --- make binary masks of whole-cell and inner, at image size ---
selectWindow("HMGB1");
getDimensions(w, h, ch, sl, fr);

newImage("wholeMask", "8-bit black", w, h, 1);
roiManager("Select", 0); setColor(255); fill(); run("Select None");
setThreshold(128,255); run("Convert to Mask");

newImage("innerMask", "8-bit black", w, h, 1);
roiManager("Select", 1); setColor(255); fill(); run("Select None");
setThreshold(128,255); run("Convert to Mask");

// --- peripheral mask = whole - inner ---
imageCalculator("Subtract create", "wholeMask", "innerMask");
rename("periphMask");

// --- remove nuclei from BOTH inner and peripheral masks ---
// keep only nuclei that fall inside the whole-cell ROI:
selectWindow("DAPI");
run("Select None");
run("Duplicate...", "title=nucMask");
// (nucMask = whole-image nuclei; subtraction below only affects
//  pixels inside our regions, so outside-cell nuclei are irrelevant)

imageCalculator("Subtract create", "innerMask", "nucMask");
rename("innerNoNuc");
imageCalculator("Subtract create", "periphMask", "nucMask");
rename("periphNoNuc");

// --- measure MGV: redirect each region-selection onto HMGB1 and Mito ---
run("Set Measurements...", "mean redirect=None decimal=3");

function measureRegion(maskTitle, targetTitle) {
    selectWindow(maskTitle);
    setThreshold(128,255);
    run("Create Selection");        // selection = the mask region
    selectWindow(targetTitle);
    run("Restore Selection");
    getStatistics(area, mean);
    run("Select None");
    return mean;
}

hmgb1_periph = measureRegion("periphNoNuc", "HMGB1");
hmgb1_inner  = measureRegion("innerNoNuc",  "HMGB1");
mito_periph  = measureRegion("periphNoNuc", "Mito");
mito_inner   = measureRegion("innerNoNuc",  "Mito");

// --- output one row to the Log ---
if (nResults==0 && getInfo("log")=="") 
    print("Cell\tHMGB1_periph\tHMGB1_inner\tMito_periph\tMito_inner");
print(cellName + "\t" + hmgb1_periph + "\t" + hmgb1_inner + "\t" + mito_periph + "\t" + mito_inner);

// --- cleanup intermediate images ---
close("wholeMask"); close("innerMask"); close("periphMask");
close("nucMask"); close("innerNoNuc"); close("periphNoNuc");
roiManager("reset");
