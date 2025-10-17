import numpy as np
from pathlib import Path
from PIL import Image
from matplotlib import pyplot as plt

home_dir = Path("D:/XRay")

for dated_folder in home_dir.glob("*"):
    for exp_folder in dated_folder.glob("*_0lmin*"):
        fig, axes = plt.subplots(1, 3)
        fig.suptitle(f"{exp_folder.parent.name} / {exp_folder.name}")
        for i, camera_folder in enumerate(exp_folder.glob("*")):
            if camera_folder.is_file():
                continue
            print(camera_folder)

            axes[i].imshow(np.array(Image.open(camera_folder / "img_14.tif")), vmax=8e3)
            axes[i].set_title(camera_folder.name)
            axes[i].tick_params(left=False, right=False, labelleft=False,
                                labelbottom=False, bottom=False)
        fig.tight_layout()
        plt.show()
