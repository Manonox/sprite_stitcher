import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["progress", "progressWidth", "form"];

    async submit(event) {
        event.preventDefault();

        let formData = new FormData(this.formTarget);

        this.progress_set(0);
        let i = 1
        let timerId = setInterval(() => {
            this.progress_set((1 - 1/i) * 80);
            i += 1;
        }, 500);
        setTimeout(() => clearInterval(timerId), 5000);

        let response = await fetch("stitch", {
            method: "POST",
            body: formData
            })
            
        clearInterval(timerId);
        
        this.progress_set(90);
        response = await response.json();
        let token = response["token"];

        this.progress_set(95);
        fetch("download?" + new URLSearchParams({token: token}), {
                method: "GET"
            })
            .then(response => response.blob())
            .then(blob => URL.createObjectURL(blob))
            .then((href) => {
                Object.assign(document.createElement('a'), {
                    href,
                    download: 'result.zip',
                }).click();
            });
        this.progress_set(100);
        setTimeout(() => {this.progress_set(0)}, 3000);
    }

    progress_set(percent) {
        this.progressWidthTarget.style.width = `${percent}%`;
    }
}