//
//  ViewController.swift
//  FreesoundKit
//
//  Copyright (c) 2018 Nikhil Singh. All rights reserved.
//

import UIKit
import FreesoundKit
import AVFoundation

struct FreesoundSound {
    let name: String?
    let id: String?
}

class ViewController: UIViewController {
    
    @IBOutlet var searchTextField: UITextField!
    @IBOutlet var tableView: UITableView!
    
    var player: AVPlayer?
    var resultSounds = [FreesoundSound]()
    
    override func viewDidLoad() {
        searchTextField.returnKeyType = .done
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        if Freesound.isAuthorized {
            Freesound.refresh()
        } else {
            Freesound.authorize {
                let alert = UIAlertController(title: "Enter Code", message: "Please enter temporary authorization code here.", preferredStyle: .alert)
                alert.addTextField(configurationHandler: nil)
                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: { _ in
                    Freesound.handleCode(alert.textFields?.first?.text ?? "")
                })
                alert.addAction(defaultAction)
                
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func searchFreesound(_ sender: UIButton) {
        guard let queryText = searchTextField.text else { return }
        Freesound.search(queryText, handler: { response in
            defer {
                self.searchTextField.resignFirstResponder()
                self.tableView.reloadData()
            }
            
            guard let sounds = response?["results"] as? [[String: Any]] else { return }
            sounds.forEach { sound in
                self.resultSounds.append(FreesoundSound(name: sound["name"] as? String, id: String(sound["id"] as! Int)))
                print(self.resultSounds)
            }
        })
    }
    
    @IBAction func downloadSound(_ sender: UIButton) {
        guard let selectedSoundIndex = tableView.indexPathForSelectedRow?.row else { return }
        let selectedSound = resultSounds[selectedSoundIndex]
        guard let id = selectedSound.id, let name = selectedSound.name else { return }
        
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        Freesound.download(id, to: documentsDir.appendingPathComponent(name), handler: { destinationUrl in
            guard let url = destinationUrl else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                let alert = UIAlertController(title: "File downloaded!", message: "\(url.lastPathComponent) is in your documents directory.", preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alert.addAction(defaultAction)
                self.present(alert, animated: true, completion: nil)
            }
        })
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultSounds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell()
        cell.textLabel?.text = resultSounds[indexPath.row].name
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedSoundID = resultSounds[indexPath.row].id else { return }
        Freesound.getPreviewURL(selectedSoundID, quality: .high, handler: { [weak self] previewUrl in
            guard let url = previewUrl else { return }
            self?.player = AVPlayer(url: url)
            guard let avPlayer = self?.player else { return }
            avPlayer.play()
        })
    }
}
